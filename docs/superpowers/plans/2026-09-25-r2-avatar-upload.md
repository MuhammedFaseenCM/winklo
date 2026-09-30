# R2 + Worker Avatar Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Firebase Storage profile-photo uploads with a Cloudflare Worker that verifies a Firebase ID token and writes `avatars/{uid}.jpg` to a public R2 bucket; Flutter stores the returned `r2.dev` URL on `users/{uid}.photoUrl`.

**Architecture:** New `AvatarUploadClient` (data layer) PUTs JPEG bytes + Bearer token to `PUT /v1/avatar`. Worker verifies Firebase JWT (Google JWKS), writes R2, returns `{ photoUrl }`. `ProfileRepositoryImpl.updateAvatarPhoto` uses the client instead of `FirebaseStorage`. Presets and Google photos unchanged.

**Tech Stack:** Flutter/Dart, `package:http`, Cloudflare Workers (TypeScript + Wrangler), R2 binding, Firebase Auth JWTs, existing Firestore profile path.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-25-r2-avatar-upload-design.md`
- Public reads via `*.r2.dev`; upload auth = Firebase ID token only
- Object key exactly `avatars/{uid}.jpg`; Content-Type `image/jpeg`; max body **2 MiB**
- Domain stays pure Dart (no Flutter / `http` in `domain/`)
- User-facing errors stay existing Failure messages / `AppStrings` (no new copy required for v1)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/core/config/avatar_upload_config.dart` | Worker base URL from `--dart-define` |
| `lib/data/clients/avatar/avatar_upload_client.dart` | Abstract upload interface |
| `lib/data/clients/avatar/r2_avatar_upload_client.dart` | HTTP PUT implementation |
| `lib/data/repositories/profile_repository_impl.dart` | Call upload client; drop Firebase Storage |
| `lib/core/di/app_repositories.dart` | Register client + inject into profile repo |
| `pubspec.yaml` | Add `http`; remove `firebase_storage` |
| `workers/avatar-upload/` | Wrangler Worker (auth + R2 put) |
| `test/data/clients/avatar/r2_avatar_upload_client_test.dart` | Client unit tests |
| `test/data/repositories/profile_repository_impl_test.dart` | Keep / extend as needed |
| `FIREBASE.md` | Document R2/Worker setup; mark Storage unused |
| `storage.rules` | Leave in place for now (unused); optional delete follow-up |

---

### Task 1: Avatar upload config + client interface

**Files:**
- Create: `lib/core/config/avatar_upload_config.dart`
- Create: `lib/data/clients/avatar/avatar_upload_client.dart`
- Test: `test/core/config/avatar_upload_config_test.dart`

**Interfaces:**
- Produces:

```dart
// lib/core/config/avatar_upload_config.dart
abstract final class AvatarUploadConfig {
  /// From `--dart-define=AVATAR_UPLOAD_BASE_URL=https://…` (no trailing slash).
  static String get baseUrl;
  static bool get isConfigured; // non-empty baseUrl
}

// lib/data/clients/avatar/avatar_upload_client.dart
abstract class AvatarUploadClient {
  /// Uploads JPEG bytes; returns the public photo URL.
  /// Throws [Failure] on HTTP/network/config errors.
  Future<Uri> uploadJpeg({
    required String idToken,
    required List<int> bytes,
  });
}
```

- [ ] **Step 1: Write the failing config test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/config/avatar_upload_config.dart';

void main() {
  test('isConfigured is false when base URL is empty', () {
    // Document: without dart-define, baseUrl defaults to ''.
    expect(AvatarUploadConfig.baseUrl, isA<String>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/config/avatar_upload_config_test.dart`  
Expected: FAIL — library not found

- [ ] **Step 3: Implement config + interface**

```dart
// lib/core/config/avatar_upload_config.dart
abstract final class AvatarUploadConfig {
  static const String baseUrl = String.fromEnvironment(
    'AVATAR_UPLOAD_BASE_URL',
    defaultValue: '',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
```

```dart
// lib/data/clients/avatar/avatar_upload_client.dart
import '../../../domain/failures.dart';

abstract class AvatarUploadClient {
  Future<Uri> uploadJpeg({
    required String idToken,
    required List<int> bytes,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/config/avatar_upload_config_test.dart`  
Expected: PASS

- [ ] **Step 5: Format**

Run: `dart format lib/core/config/avatar_upload_config.dart lib/data/clients/avatar/avatar_upload_client.dart test/core/config/avatar_upload_config_test.dart`

---

### Task 2: `R2AvatarUploadClient` (HTTP) + tests

**Files:**
- Create: `lib/data/clients/avatar/r2_avatar_upload_client.dart`
- Modify: `pubspec.yaml` — add `http`
- Test: `test/data/clients/avatar/r2_avatar_upload_client_test.dart`

**Interfaces:**
- Consumes: `AvatarUploadClient`, `AvatarUploadConfig.baseUrl`
- Produces:

```dart
class R2AvatarUploadClient implements AvatarUploadClient {
  R2AvatarUploadClient({
    required this.baseUrl,
    http.Client? httpClient,
  });

  final String baseUrl;
  // PUT `$baseUrl/v1/avatar`
}
```

- [ ] **Step 1: Add dependency**

Run: `flutter pub add http`  
Expected: `http` listed in `pubspec.yaml`

- [ ] **Step 2: Write failing client tests**

Use a fake `http.Client` (hand-rolled or `mocktail` + custom) that records the request:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winklo/data/clients/avatar/r2_avatar_upload_client.dart';
import 'package:winklo/domain/failures.dart';

void main() {
  test('PUT sends Bearer token and JPEG body; returns photoUrl', () async {
    final client = R2AvatarUploadClient(
      baseUrl: 'https://avatar.example',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.toString(), 'https://avatar.example/v1/avatar');
        expect(request.headers['Authorization'], 'Bearer tok');
        expect(request.headers['Content-Type'], 'image/jpeg');
        expect(request.bodyBytes, [1, 2, 3]);
        return http.Response(
          jsonEncode({
            'photoUrl': 'https://pub.example/avatars/u1.jpg',
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      }),
    );

    final uri = await client.uploadJpeg(idToken: 'tok', bytes: [1, 2, 3]);
    expect(uri.toString(), 'https://pub.example/avatars/u1.jpg');
  });

  test('401 throws Failure', () async {
    final client = R2AvatarUploadClient(
      baseUrl: 'https://avatar.example',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"unauthorized"}', 401),
      ),
    );

    expect(
      () => client.uploadJpeg(idToken: 'bad', bytes: [1]),
      throwsA(isA<Failure>()),
    );
  });

  test('empty baseUrl throws Failure before HTTP', () async {
    final client = R2AvatarUploadClient(baseUrl: '');
    expect(
      () => client.uploadJpeg(idToken: 'tok', bytes: [1]),
      throwsA(isA<Failure>()),
    );
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/data/clients/avatar/r2_avatar_upload_client_test.dart`  
Expected: FAIL — class not found

- [ ] **Step 4: Implement client**

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../domain/failures.dart';
import 'avatar_upload_client.dart';

class R2AvatarUploadClient implements AvatarUploadClient {
  R2AvatarUploadClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const _maxBytes = 2 * 1024 * 1024;

  @override
  Future<Uri> uploadJpeg({
    required String idToken,
    required List<int> bytes,
  }) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw const Failure('Avatar upload is not configured.');
    }
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const Failure('Could not update profile.');
    }

    final uri = Uri.parse('$root/v1/avatar');
    final response = await _http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Failure(
        'Could not update profile.',
        cause: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const Failure('Could not update profile.');
    }
    final photoUrl = decoded['photoUrl'];
    if (photoUrl is! String || photoUrl.isEmpty) {
      throw const Failure('Could not update profile.');
    }
    return Uri.parse(photoUrl);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/data/clients/avatar/r2_avatar_upload_client_test.dart`  
Expected: PASS

- [ ] **Step 6: Format**

Run: `dart format lib/data/clients/avatar/r2_avatar_upload_client.dart test/data/clients/avatar/r2_avatar_upload_client_test.dart`

---

### Task 3: Wire `ProfileRepositoryImpl` + DI; remove Firebase Storage

**Files:**
- Modify: `lib/data/repositories/profile_repository_impl.dart`
- Modify: `lib/core/di/app_repositories.dart`
- Modify: `pubspec.yaml` — remove `firebase_storage`
- Test: extend `test/data/repositories/profile_repository_impl_test.dart` only if new pure helpers appear; otherwise rely on client tests + manual

**Interfaces:**
- Consumes: `AvatarUploadClient`
- `ProfileRepositoryImpl` constructor gains `AvatarUploadClient? avatarUploadClient` (required in production DI)

- [ ] **Step 1: Update repository constructor and `updateAvatarPhoto`**

Replace Firebase Storage upload with:

```dart
@override
Future<AppUser> updateAvatarPhoto(
  List<int> bytes, {
  String contentType = 'image/jpeg',
}) async {
  final db = _requireDb();
  final authUser = _requireAuthUser();
  final uploader = _avatarUploadClient;
  if (uploader == null) {
    throw const Failure('Avatar upload is not configured.');
  }
  try {
    // v1: only JPEG path is supported by Worker.
    if (contentType != 'image/jpeg' && contentType != 'image/jpg') {
      throw const Failure('Could not update profile.');
    }
    final idToken = await authUser.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const Failure('Sign in required.');
    }
    final photoUri = await uploader.uploadJpeg(
      idToken: idToken,
      bytes: bytes,
    );
    final photoUrl = photoUri.toString();
    await db.collection('users').doc(authUser.uid).set({
      'photoUrl': photoUrl,
      'avatarId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await authUser.updatePhotoURL(photoUrl);
    final profile = await _loadProfile(db, authUser.uid);
    await _denormalizeLeaderboards(db, profile);
    return profile;
  } on Failure {
    rethrow;
  } catch (e, st) {
    debugPrint('updateAvatarPhoto failed: $e');
    debugPrint('$st');
    throw Failure('Could not update profile.', cause: e);
  }
}
```

Remove `import 'package:firebase_storage/...'`, `_storage` field, `_bucket` getter.

Add field:

```dart
final AvatarUploadClient? _avatarUploadClient;
```

- [ ] **Step 2: Register in DI**

In `buildRepositoryProviders`:

```dart
RepositoryProvider<AvatarUploadClient>(
  create: (_) => R2AvatarUploadClient(
    baseUrl: AvatarUploadConfig.baseUrl,
  ),
),
RepositoryProvider<ProfileRepository>(
  create: (context) => ProfileRepositoryImpl(
    avatarUploadClient: context.read<AvatarUploadClient>(),
  ),
),
```

Add imports for config + clients.

- [ ] **Step 3: Remove firebase_storage**

Run: `flutter pub remove firebase_storage`  
Expected: dependency gone from `pubspec.yaml` / lockfile

- [ ] **Step 4: Analyze + targeted tests**

Run:

```bash
dart analyze lib/data/repositories/profile_repository_impl.dart lib/core/di/app_repositories.dart lib/data/clients/avatar/
flutter test test/data/clients/avatar/ test/data/repositories/profile_repository_impl_test.dart test/features/profile/
```

Expected: No analyzer issues; tests PASS

- [ ] **Step 5: Format changed Dart files**

Run: `dart format lib/data/repositories/profile_repository_impl.dart lib/core/di/app_repositories.dart`

---

### Task 4: Cloudflare Worker scaffolding

**Files:**
- Create: `workers/avatar-upload/package.json`
- Create: `workers/avatar-upload/tsconfig.json`
- Create: `workers/avatar-upload/wrangler.toml`
- Create: `workers/avatar-upload/src/index.ts` (stub health route)
- Create: `workers/avatar-upload/README.md` (local deploy steps)

**Interfaces:**
- Produces Worker with:
  - `GET /v1/health` → `{"ok":true}`
  - Env: `FIREBASE_PROJECT_ID`, `PUBLIC_BASE_URL`, R2 binding `AVATARS`

- [ ] **Step 1: Scaffold Wrangler project**

```toml
# workers/avatar-upload/wrangler.toml
name = "winklo-avatar-upload"
main = "src/index.ts"
compatibility_date = "2026-09-01"

[[r2_buckets]]
binding = "AVATARS"
bucket_name = "winklo-avatars"

[vars]
FIREBASE_PROJECT_ID = "brain-zip-app"
# PUBLIC_BASE_URL set after enabling r2.dev — e.g. https://pub-xxxxx.r2.dev
PUBLIC_BASE_URL = ""
```

```json
// workers/avatar-upload/package.json
{
  "name": "winklo-avatar-upload",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250901.0",
    "typescript": "^5.6.0",
    "vitest": "^3.0.0",
    "wrangler": "^4.0.0"
  },
  "dependencies": {
    "jose": "^5.9.0"
  }
}
```

- [ ] **Step 2: Stub Worker**

```typescript
// workers/avatar-upload/src/index.ts
export interface Env {
  AVATARS: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  PUBLIC_BASE_URL: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/v1/health') {
      return Response.json({ ok: true });
    }
    return new Response('Not found', { status: 404 });
  },
};
```

- [ ] **Step 3: Install + typecheck locally**

Run from `workers/avatar-upload`:

```bash
npm install
npx tsc --noEmit
```

Expected: success (add minimal `tsconfig.json` for Workers)

- [ ] **Step 4: Document ops in Worker README**

Include: create R2 bucket `winklo-avatars`, enable public `r2.dev` URL, set `PUBLIC_BASE_URL`, `wrangler deploy`, Flutter `--dart-define=AVATAR_UPLOAD_BASE_URL=…`

---

### Task 5: Worker JWT verify + R2 upload

**Files:**
- Modify: `workers/avatar-upload/src/index.ts`
- Create: `workers/avatar-upload/src/firebase_auth.ts`
- Create: `workers/avatar-upload/src/upload.ts`
- Test: `workers/avatar-upload/src/upload.test.ts` (pure validation helpers)

**Interfaces:**
- Produces: `PUT /v1/avatar` behavior per spec

- [ ] **Step 1: Write pure validation helper + failing test**

```typescript
// workers/avatar-upload/src/upload.ts
export const MAX_BYTES = 2 * 1024 * 1024;

export function validateJpegRequest(
  contentType: string | null,
  byteLength: number,
): 'ok' | 'invalid_image' {
  const type = (contentType ?? '').split(';')[0].trim().toLowerCase();
  if (type !== 'image/jpeg') return 'invalid_image';
  if (byteLength <= 0 || byteLength > MAX_BYTES) return 'invalid_image';
  return 'ok';
}

export function objectKeyForUid(uid: string): string {
  return `avatars/${uid}.jpg`;
}

export function publicPhotoUrl(publicBaseUrl: string, uid: string): string {
  const base = publicBaseUrl.replace(/\/+$/, '');
  return `${base}/avatars/${uid}.jpg`;
}
```

```typescript
// workers/avatar-upload/src/upload.test.ts
import { describe, expect, it } from 'vitest';
import {
  objectKeyForUid,
  publicPhotoUrl,
  validateJpegRequest,
} from './upload';

describe('validateJpegRequest', () => {
  it('accepts image/jpeg under limit', () => {
    expect(validateJpegRequest('image/jpeg', 100)).toBe('ok');
  });
  it('rejects wrong type', () => {
    expect(validateJpegRequest('image/png', 100)).toBe('invalid_image');
  });
  it('rejects oversized', () => {
    expect(validateJpegRequest('image/jpeg', 3 * 1024 * 1024)).toBe(
      'invalid_image',
    );
  });
});

describe('keys', () => {
  it('builds object key and public URL', () => {
    expect(objectKeyForUid('u1')).toBe('avatars/u1.jpg');
    expect(publicPhotoUrl('https://pub.example/', 'u1')).toBe(
      'https://pub.example/avatars/u1.jpg',
    );
  });
});
```

- [ ] **Step 2: Run vitest**

Run: `cd workers/avatar-upload && npm test`  
Expected: PASS for helpers

- [ ] **Step 3: Implement Firebase JWT verification**

```typescript
// workers/avatar-upload/src/firebase_auth.ts
import { createRemoteJWKSet, jwtVerify } from 'jose';

// Google x509 endpoint is not JWKS; use:
// https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
const JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
);

export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<{ uid: string }> {
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  const uid = payload.sub;
  if (!uid) throw new Error('missing sub');
  return { uid };
}
```

- [ ] **Step 4: Wire PUT handler in `index.ts`**

Logic:

1. `OPTIONS` → 204 with CORS headers if needed  
2. `PUT /v1/avatar` only  
3. Parse `Authorization: Bearer …` → else 401  
4. `verifyFirebaseIdToken` → else 401  
5. Read body `arrayBuffer()`; `validateJpegRequest` → else 400  
6. Require non-empty `PUBLIC_BASE_URL` → else 500  
7. `env.AVATARS.put(objectKeyForUid(uid), body, { httpMetadata: { contentType: 'image/jpeg', cacheControl: 'public, max-age=3600' } })`  
8. Return `200 { photoUrl: publicPhotoUrl(...) }`  
9. Catch R2 errors → 502 `{ error: "upload_failed" }`

- [ ] **Step 5: Deploy (human + agent with CF credentials)**

```bash
cd workers/avatar-upload
npx wrangler deploy
```

Set `PUBLIC_BASE_URL` to the bucket’s public `r2.dev` base after enabling it in Cloudflare dashboard.

- [ ] **Step 6: Smoke curl (with a real ID token from a debug print once)**

```bash
curl -i -X PUT "$WORKER_URL/v1/avatar" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/path/to/small.jpg
```

Expected: `200` + `photoUrl`; opening URL shows the image

---

### Task 6: Docs + run instructions

**Files:**
- Modify: `FIREBASE.md` — replace / amend §8 Cloud Storage with R2 + Worker
- Modify: `docs/superpowers/specs/2026-09-25-r2-avatar-upload-design.md` — set Status to `approved; plan ready`

- [ ] **Step 1: Update FIREBASE.md**

Document:

1. No Firebase Storage / Blaze required for avatars  
2. Cloudflare R2 bucket + public `r2.dev`  
3. Worker deploy from `workers/avatar-upload`  
4. Flutter run example:

```bash
flutter run --dart-define=AVATAR_UPLOAD_BASE_URL=https://winklo-avatar-upload.<account>.workers.dev
```

5. Manual checklist: upload photo → Profile + Leaderboard show image; preset still clears `photoUrl`

- [ ] **Step 2: Confirm Flutter analyze on touched tree**

Run:

```bash
dart analyze lib/core/config/avatar_upload_config.dart lib/data/clients/avatar lib/data/repositories/profile_repository_impl.dart lib/core/di/app_repositories.dart
flutter test test/core/config/avatar_upload_config_test.dart test/data/clients/avatar/
```

Expected: clean + PASS

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| PUT Worker + Firebase JWT | 5 |
| R2 `avatars/{uid}.jpg` + public URL | 5 |
| Flutter client + dart-define | 1–2 |
| ProfileRepository uses client | 3 |
| Remove firebase_storage | 3 |
| Validation 2 MiB / jpeg | 2, 5 |
| Best-effort denormalize kept | 3 |
| Ops / FIREBASE.md | 4, 6 |
| Tests client + worker helpers | 2, 5 |

## Placeholder scan

No TBD / “implement later” steps. Exact paths, commands, and code included.

## Type consistency

- `AvatarUploadClient.uploadJpeg({ idToken, bytes }) → Future<Uri>` used in Task 2–3  
- Worker returns JSON `photoUrl` string matching client parse  
- Object key / public URL helpers shared naming `avatars/{uid}.jpg`
