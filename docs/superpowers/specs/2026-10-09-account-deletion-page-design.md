# Account deletion page — design

Date: 2026-10-09  
Status: approved for planning  
Scope: Dedicated web deletion page + Cloudflare Worker that verifies Google Sign-In and immediately wipes the signed-in user’s Winklo cloud data and Auth account. Dual-host publish for Play Data Safety.

## Goal

Ship a dedicated, globally reachable account/data deletion URL that:

1. Proves identity with **Google Sign-In** (Firebase ID token).
2. **Immediately** deletes that user’s Winklo-held cloud data and Firebase Auth account after explicit confirm.
3. Serves on **Cloudflare Pages** and **GitHub Pages** so Play Console can crawl a stable public URL.

Canonical Play URL: `https://winklo.pages.dev/delete-account/`  
Mirror: `https://muhammedfaseencm.github.io/winklo/delete-account/`

## Decisions

| Topic | Choice |
| --- | --- |
| Request UX | Real web form with Google Sign-In (not GitHub-issue-only) |
| Backend | New Cloudflare Worker `workers/account-deletion` → Firestore (audit) + privileged wipe |
| Identity | Firebase Web Google Sign-In → Bearer ID token to Worker |
| Wipe timing | Immediate on confirmed submit (no 30-day delay as primary path) |
| Hosts | Both Pages hosts; Data Safety declares Cloudflare URL |
| Admin SPA triage | Out of scope for v1 (audit docs only) |
| In-app Profile delete button | Out of scope for v1 |

## Architecture

```
Browser (docs/delete-account/)
  │  Firebase Web SDK: Google Sign-In → ID token
  ▼
POST /v1/delete-account
Authorization: Bearer <Firebase ID token>
Body: { "confirm": "DELETE" }
  │
  ▼
workers/account-deletion
  1. Verify JWT (jose + Google securetoken JWKS; same idea as avatar-upload)
  2. uid = token.sub
  3. Delete R2 object avatars/{uid}.jpg (ignore missing)
  4. Admin-delete Firestore data for uid (see Deletion scope)
  5. Delete Firebase Auth user (Identity Toolkit Admin)
  6. Write audit doc deletion_requests/{id}
  7. Return { ok: true }
```

| Piece | Detail |
| --- | --- |
| Page | `docs/delete-account/index.html` — self-contained HTML/CSS/JS; visual tokens match privacy page |
| Deploy docs | Existing Cloudflare Pages workflow on `docs/`; GitHub Pages already serves `/docs` |
| CORS | Allow only `https://winklo.pages.dev` and `https://muhammedfaseencm.github.io` |
| Firebase Auth | Add both hosts under Authorized domains before launch |

## Page flow

1. Brand **Winklo** + title **Delete your Winklo account**.
2. Short copy: irreversible; summarizes what is deleted; states deletion is **immediate** after confirm (not a 30-day queue).
3. **Continue with Google**.
4. After sign-in: show email and uid; checkbox “I understand this cannot be undone”; user must type `DELETE` to enable the button.
5. Submit → loading → success (“Account deleted. You can close this page.”) or error with retry.
6. Footer link to privacy policy (`../privacy/` or absolute Pages URL).

Firebase Web config on the page uses the same project as the app (public web config only; no service account in the browser).

## Deletion scope

For the authenticated `uid` only.

### Delete

- `users/{uid}`
- Subcollections: `users/{uid}/game_days/*`, `game_days_debug/*`, `game_streaks/*`, `game_streaks_debug/*`
- Leaderboard docs keyed by uid:
  - `leaderboards/{zip\|path_words\|sudoku}/all_time/{uid}`
  - `leaderboards_debug/.../all_time/{uid}`
  - Daily: under each game, list `daily/{dayId}/entries/{uid}` (and debug twin) and delete when present
- `issue_reports` where `uid == requester` (query + delete)
- `daily_activity/{dayId}/users/{uid}` — **best-effort** (Admin list/query; record partial if incomplete)
- R2 object `avatars/{uid}.jpg`
- Firebase Auth user for that uid

### Do not delete

- Puzzle catalogs and other content collections
- Remote Config
- Analytics / Crashlytics historical events (not stored as user-owned Firestore docs we control)
- Other users’ data
- Preset static R2 assets under `static/avatars/`

### Audit document

Always attempt to write `deletion_requests/{autoId}`:

| Field | Type | Notes |
| --- | --- | --- |
| `uid` | string | From verified token |
| `email` | string \| null | From token claims when present |
| `requestedAt` | timestamp | Server time at start |
| `completedAt` | timestamp \| null | Set when finished |
| `status` | string | `completed` \| `partial` \| `failed` |
| `steps` | map | Booleans or status per `firestore`, `r2`, `auth` |
| `errorMessage` | string \| null | Safe, non-sensitive summary |

Client cannot create or read this collection; Worker uses Admin credentials only. Add Firestore rules that deny all client access to `deletion_requests`.

## Worker API

- **Method/path:** `POST /v1/delete-account`
- **Auth:** `Authorization: Bearer <Firebase ID token>`
- **Body:** `{ "confirm": "DELETE" }` (required; reject otherwise with 400)
- **Responses:**
  - `200` `{ "ok": true }`
  - `401` missing/invalid token
  - `400` confirm missing/wrong
  - `429` short cooldown / abuse guard after repeated failures for same uid (successful delete is naturally once)
  - `500` unexpected; generic message only

Reuse JWT verification approach from `workers/avatar-upload` (`verifyFirebaseIdToken` + project id). Prefer a small shared copy or duplicated helper in the new worker package (no monorepo package required for v1).

R2: bind the same `winklo-avatars` bucket used by avatar-upload; delete key `avatars/{uid}.jpg`.

Firestore + Auth Admin: service account secret (same operational pattern as `winklo-admin` `admin-api`).

## Privacy, Play, and app updates

- Update `docs/privacy/index.html` “Your choices and account deletion”: primary path is the deletion page (immediate wipe after Google confirm); GitHub issues remain for questions or failed requests only.
- `play/data_safety.csv`: set `PSL_ACCOUNT_DELETION_URL` and `PSL_DATA_DELETION_URL` to `https://winklo.pages.dev/delete-account/`.
- `play/app_content_answers.txt`: same URL and note immediate web deletion.
- Optional: landing footer link “Delete account” on `docs/index.html`.
- Optional: `AppUrls.accountDeletion` in Flutter for a future WebView — **not required** to clear Play.
- README: retire the “deletion only via GitHub issue” known limitation for the web path.

## Ops checklist

1. Create and deploy `workers/account-deletion` with secrets + R2 binding.
2. Deploy `docs/` (Cloudflare Pages workflow; GitHub Pages auto-builds `/docs`).
3. Add authorized domains: `winklo.pages.dev`, `muhammedfaseencm.github.io`.
4. Smoke-test delete on a throwaway Google account on **both** hosts.
5. Update Play Data Safety URLs → Send for review.

## Non-goals (v1)

- In-app Profile “Delete account” button
- winklo-admin list/triage UI for `deletion_requests`
- Soft-delete or grace period
- Purging Google Analytics / Crashlytics history
- Non-Google account types

## Risks

- Daily leaderboard and `daily_activity` cleanup may be incomplete without exhaustive collection-group deletes; accept **best-effort** and mark audit `partial` when a step fails.
- Missing Auth authorized domain on one host → Sign-In fails there; test both before Play re-submit.
- Service account permissions must include Firestore delete, Auth user delete, and R2 object delete.

## Success criteria

- Both host URLs return HTTP 200 with a clear deletion page.
- A test account can complete Google Sign-In → confirm → delete; Auth user and `users/{uid}` are gone afterward.
- Unauthenticated requests and wrong/missing `confirm` are rejected.
- Play Data Safety points at `https://winklo.pages.dev/delete-account/`.
- Privacy policy no longer presents GitHub-issue / 30-day delay as the primary deletion path.
