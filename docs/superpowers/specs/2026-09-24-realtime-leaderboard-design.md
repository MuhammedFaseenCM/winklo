# Realtime leaderboard (Google Auth + Firestore) — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

Ship a **real-time** per-game leaderboard with **real Google-signed-in users** for the live games (Zip and Path Words), with Daily and All-time boards ranked by fastest completion time.

## Product decisions

| Topic | Choice |
|-------|--------|
| Identity | Google Sign-In → Firebase Auth |
| Sign-in gate | Required before playing Zip / Path Words |
| Games | Zip + Path Words only (Word Match / Category Race out of scope) |
| Boards | Per-game; Daily (UTC) + All-time tabs |
| Ranking | Fastest `timeSeconds` wins (not points) |
| Ties | Same `timeSeconds` → same dense rank (1, 2, 2, 3); `updatedAt` only orders rows within a tie |
| Backend | Firestore client writes + live `snapshots()` (Approach 1) |
| Local scores | Unchanged SharedPreferences; sync best time when improved |

## Approach

**Approach 1 — Firestore client writes + live snapshots** (chosen over Cloud Functions submit and over Realtime Database): fits existing Firebase/Firestore stack and reserved `AuthRepository` / `LeaderboardRepository` architecture. Rules reduce cheating; Cloud Functions can be added later if needed.

## Architecture

```
Google Sign-In → Firebase Auth
        │
AuthRepository / LeaderboardRepository (domain)
        │
AuthRepositoryImpl / LeaderboardRepositoryImpl (data)
        │
EnsureSignedIn → Home Play gate → Zip / Path Words
SubmitScore (local) → on time improve → SubmitLeaderboardTime
Leaderboard Cubit ← WatchLeaderboard ← Firestore snapshots()
```

## Data model

```
users/{uid}: displayName, photoUrl, updatedAt

leaderboards/{gameId}/all_time/{uid}:
  timeSeconds, updatedAt, displayName, photoUrl

leaderboards/{gameId}/daily/{yyyy-MM-dd}/entries/{uid}:
  timeSeconds, updatedAt, displayName, photoUrl

gameId ∈ { zip, path_words }
Daily date key: UTC yyyy-MM-dd
```

**Query:** `orderBy timeSeconds asc`, then `orderBy updatedAt asc`, `limit(50)`. Client assigns dense ranks (equal times share a place).

**Writes:** own doc only; improve-only (new time strictly less than existing). Submit updates all-time and today’s daily.

## App layer

- **Domain:** `AppUser`, `LeaderboardEntry`, `LeaderboardPeriod`; `AuthRepository`, `LeaderboardRepository`; usecases `SignInWithGoogle`, `SignOut`, `WatchLeaderboard`, `SubmitLeaderboardTime`, `EnsureSignedIn`.
- **Data:** Firebase Auth + Google Sign-In; Firestore streams/transactions; fail soft when `FirebaseBootstrap.isReady == false`.
- **Features:** `features/auth/` (Cubit + sign-in sheet); `features/leaderboard/` (Cubit + screen with game + period tabs); Home avatar / Play gate / leaderboard entry; route `/leaderboard`.
- **DI:** extend `MultiRepositoryProvider` in `app_repositories.dart`.
- **Copy:** all user-facing strings via `AppStrings`.

## Security

- Content collections remain public-read / no client write.
- `users/{uid}`: signed-in read; write only own uid.
- Leaderboard paths: signed-in read; write only own uid; `gameId` whitelist; `timeSeconds` int > 0; update requires strictly lower time.
- Composite indexes on `timeSeconds` + `updatedAt`.
- Ops: enable Google provider; Android OAuth / SHA-1; document in `FIREBASE.md`.

## Errors / fail-soft

- Firebase not ready → clear auth/leaderboard messaging; do not brick solo local scores.
- Sign-in cancel → stay on Home.
- Leaderboard stream error → error state + retry.
- Remote submit failure after local best → keep local score; best-effort sync (log / optional snackbar).

## Privacy

Store only uid, displayName, photoUrl, timeSeconds, updatedAt. Update Play Data Safety if Google account identity is newly disclosed.

## Testing

- Repository / usecase unit tests with mocks.
- Auth + Leaderboard Cubit `bloc_test`.
- Home Play gate: signed-out → sign-in; signed-in → navigate.
- Zip / Path Words bloc tests mock `SubmitLeaderboardTime`.
- Rules/indexes: manual checklist in `FIREBASE.md`.

## Out of scope

- Cloud Functions anti-cheat
- Word Match / Category Race boards
- Points-based ranking
- Anonymous auth
- Changing local score formula
