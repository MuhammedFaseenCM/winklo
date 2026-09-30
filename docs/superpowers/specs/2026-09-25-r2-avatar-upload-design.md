# Cloudflare R2 + Worker avatar uploads — design

Date: 2026-09-25  
Status: approved; plan ready

## Goal

Replace **Firebase Storage** for custom profile photos with **Cloudflare R2** (public `r2.dev` URLs) plus a **Cloudflare Worker** that authenticates uploads with a **Firebase ID token**. Stay on Firebase Spark for Auth/Firestore; avoid Blaze.

## Product decisions

| Topic | Choice |
|-------|--------|
| Storage | Cloudflare R2 |
| Public reads | Yes — public object URLs on `*.r2.dev` |
| Upload auth | Firebase ID token verified in Worker |
| Upload API | `PUT` raw `image/jpeg` body to Worker |
| Object key | `avatars/{uid}.jpg` (overwrite on re-upload) |
| URL stored in | `users/{uid}.photoUrl` (same field as today) |
| Presets | Unchanged — bundled assets, no R2 |
| Google photo | Unchanged — Auth `photoUrl` until user picks preset or uploads |
| Firebase Storage | Remove from upload path; drop `firebase_storage` dependency when unused |

## Out of scope

- Custom domain for avatars (upgrade path later)
- Private / signed GET URLs
- Presigned client→R2 PUT
- Image transforms (Cloudflare Images)
- Deleting R2 objects on account deletion (can add later)

## Architecture

```
Flutter (signed-in)
  ImagePicker → optional client compress
       │
       ▼
  PUT https://<worker-host>/v1/avatar
       Authorization: Bearer <Firebase ID token>
       Content-Type: image/jpeg
       body: JPEG bytes (max 2 MiB after client compress)
       │
       ▼
  Cloudflare Worker
       1. Verify Firebase JWT (Google JWKS, aud = Firebase project)
       2. uid = token.sub
       3. Validate content-type + size
       4. R2.put("avatars/{uid}.jpg", body, { httpMetadata })
       5. Return { "photoUrl": "https://pub-<id>.r2.dev/avatars/{uid}.jpg" }
       │
       ▼
  ProfileRepositoryImpl
       Firestore users/{uid}: photoUrl = returned URL, avatarId delete
       Auth updatePhotoURL(url)
       Best-effort leaderboard identity denormalize (existing)
```

Reads: existing `UserAvatar` → `NetworkImage(photoUrl)` when no preset.

### Folder / component layout

| Piece | Location |
|-------|----------|
| Worker (new) | `workers/avatar-upload/` — Wrangler project (TypeScript) |
| Upload client | `lib/data/clients/avatar/r2_avatar_upload_client.dart` |
| Profile repo | `lib/data/repositories/profile_repository_impl.dart` — call client instead of Firebase Storage |
| Config | `lib/core/config/avatar_upload_config.dart` — Worker base URL (compile-time / `--dart-define`) |
| Domain | Unchanged `ProfileRepository.updateAvatarPhoto` / `UpdateAvatar.photo` |
| Docs | `FIREBASE.md` → add Cloudflare section; Storage setup notes become “legacy / unused” |
| Rules | Keep `storage.rules` unused or delete in follow-up; no Firestore rule change required for URL string |

### State ownership

- **Auth** — existing `AuthCubit` / Firebase Auth (source of ID token)
- **Profile write** — existing `ProfileCubit` → `UpdateAvatar.photo`
- **Worker** — stateless; no durable app state

## Worker behavior

### Endpoint

- `PUT /v1/avatar`
- Optional health: `GET /v1/health` → `200 {"ok":true}`

### Auth

1. Require `Authorization: Bearer <token>`
2. Verify JWT against Google certs (`https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com`)
3. Check `iss` = `https://securetoken.google.com/<FIREBASE_PROJECT_ID>`, `aud` = `<FIREBASE_PROJECT_ID>`, `exp` valid
4. Use `sub` as `uid` (never trust a client-supplied uid)

Secrets / vars (Wrangler):

- `FIREBASE_PROJECT_ID` (plain)
- R2 bucket binding `AVATARS`
- `PUBLIC_BASE_URL` — `https://pub-….r2.dev` (no trailing slash)

### Validation

- `Content-Type` must be `image/jpeg` (normalize; reject others for v1)
- Body size ≤ **2 MiB** (Worker rejects larger; client should compress first)
- Empty body → `400`

### R2 write

- Key: `avatars/{uid}.jpg`
- Overwrite existing
- `httpMetadata`: `contentType: image/jpeg`, optional `cacheControl: public, max-age=3600`
- Response `200`: `{ "photoUrl": "${PUBLIC_BASE_URL}/avatars/{uid}.jpg" }`
- Cache-busting: app may append `?v=<updatedAt millis>` when writing Firestore if stale CDN is an issue; v1 can omit and rely on overwrite + short cache

### Errors

| Case | Status | Body |
|------|--------|------|
| Missing/invalid token | 401 | `{ "error": "unauthorized" }` |
| Too large / bad type | 400 | `{ "error": "invalid_image" }` |
| R2 failure | 502 | `{ "error": "upload_failed" }` |

CORS: allow app origins needed for web if ever used; Android/iOS native HTTP needs no CORS. Include `OPTIONS` if testing from browser.

## Flutter / data layer

### Upload client

```dart
abstract class AvatarUploadClient {
  Future<Uri> uploadJpeg({
    required String idToken,
    required List<int> bytes,
  });
}
```

Implementation: `http`/`package:http` PUT to `${baseUrl}/v1/avatar` with Bearer token; parse `photoUrl`.

### ProfileRepositoryImpl.updateAvatarPhoto

1. `idToken = await auth.currentUser.getIdToken()`
2. Optionally compress/resize bytes (max edge ~512–1024, JPEG quality ~85) before upload — keep under 2 MiB
3. `photoUrl = await uploadClient.uploadJpeg(...)`
4. Firestore merge: `photoUrl`, `avatarId: FieldValue.delete()`, `updatedAt`
5. `authUser.updatePhotoURL(photoUrl)`
6. Reload profile + best-effort denormalize (existing)

On Worker/network failure → `Failure('Could not update profile.', cause: e)` (existing UX).

### DI

- Register `AvatarUploadClient` + config URL in `app_repositories.dart`
- Remove `FirebaseStorage` usage from profile path; remove `firebase_storage` from `pubspec.yaml` if nothing else imports it

### Config

- `--dart-define=AVATAR_UPLOAD_BASE_URL=https://…workers.dev` (or similar)
- Document default for local/debug in `FIREBASE.md` / README snippet

## Cloudflare console setup (ops checklist)

1. Create Cloudflare account; enable **R2**
2. Create bucket (e.g. `winklo-avatars`)
3. Enable **Public Development URL** (`r2.dev`) for the bucket; copy public base URL
4. Create Worker; bind R2 bucket as `AVATARS`
5. Set `FIREBASE_PROJECT_ID=brain-zip-app`, `PUBLIC_BASE_URL=https://pub-….r2.dev`
6. Deploy Worker; copy Worker URL into Flutter dart-define
7. Smoke-test: signed-in PUT with real JWT → object visible at public URL

## Security notes

- Never embed R2 API tokens in the app
- Worker is the only writer; public bucket is read-only from the internet’s perspective for listing if R2 public access is object-URL-only (no bucket listing)
- Anyone who knows `{uid}` can **read** the avatar URL (acceptable; same as public Google photos)
- Only the Firebase-authenticated owner can **write** their object
- Rate-limit consideration: rely on Cloudflare defaults for v1; add simple per-uid throttle later if abused

## Testing

| Layer | What |
|-------|------|
| Worker unit | JWT reject/accept mocks; size/type rejection (Miniflare or vitest) |
| Flutter client | Mock HTTP: success returns Uri; 401/400 map to Failure |
| Profile repo | Mock `AvatarUploadClient` — Firestore/Auth paths unchanged |
| Widget | Existing avatar sheet; no Storage dependency |
| Manual | Upload photo on device → Profile + Leaderboard show new image |

## Migration

- Existing users with Google `photoUrl` only: unchanged
- No Firebase Storage objects to migrate (Storage never enabled)
- Preset users: unchanged

## Success criteria

1. Gallery upload works on Spark (no Firebase Storage / Blaze)
2. Returned URL loads in `UserAvatar` / leaderboard
3. Re-upload overwrites same key; profile updates
4. Invalid/missing token cannot write another user’s object
5. Preset select still clears custom `photoUrl` in Firestore (R2 orphan OK for v1)

## Open follow-ups (not blocking)

- Custom domain instead of `r2.dev`
- Delete R2 object when switching to preset
- Stronger client-side encode (e.g. `flutter_image_compress`)
