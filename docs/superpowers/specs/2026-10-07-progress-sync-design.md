# Progress sync + leaderboard backfill — design

Date: 2026-10-07
Status: approved for implementation
Repos: winklo

## Goal

1. **Leaderboard backfill.** Build 1.0.0+14 wrote `currentStreak` to leaderboard docs before the rules allowed it, so every leaderboard submit on 2026-10-07 (until rules fix `e8970b7`) failed silently. Those players are locked out of replaying today. When they open the next build, their already-finished clears must appear on **today's daily leaderboard** (and all-time) automatically.
2. **Remote progress.** Per-user progress that today lives only in SharedPreferences must also live in Firestore under the user's account, so it survives reinstall / new device, can be restored, and can re-drive leaderboard sync whenever a submit fails (offline, rules mismatch, crash).

## Product decisions

- **What syncs (per-user progress):** daily clears (best time, best points, usedHints, hadMistakes, clear time), hint quota used per day, streaks (current, longest, lastClearedDateId, freezeAvailable).
- **What stays local:** in-progress run drafts (high-churn, device-specific), tutorial-seen flags, SFX mute, notification-permission-prompted flag, activity throttle, Path Words noun cache. Word Match / Category Race (`match_*`, `race_*` best keys) are legacy modes not on any board — not synced.
- **Remote progress is private** (owner-only read/write). It is never put on `users/{uid}` (readable by every signed-in user and re-emits `AuthCubit` on every write).
- **Leaderboard backfill window:** the current play period and the previous one (today + yesterday in release). Older days are not re-posted to daily boards.
- **Unknown clean-run flags (legacy clears made before this build):**
  - `usedHints` = `hintsUsed for that game+playId > 0` (hint quota is consumed for every hint, so 0 ⇒ certainly no hints; >0 may over-report — conservative).
  - `hadMistakes` = `false` for Zip and Path Words (these games have no mistake concept; their blocs always send `false`), `true` for Sudoku (unknown ⇒ conservative, matches results-screen `?? true`).
  - Remote day doc records `flagsKnown: false` for these.
- **Account switch on one device:** local progress belongs to one owner uid. If a different uid signs in, local progress keys are purged and that account's remote progress is restored. Legacy data (no owner marker yet) is claimed by the first uid that syncs.
- **Errors are no longer silent:** sync failures are reported to `client_errors` (once per sync run, `source: handled`, code `progress_sync_failed`).

## Approach

Local SharedPreferences stays the synchronous source the UI reads (locks, Home, quota). A single orchestrating use case, **`SyncProgress`**, reconciles local ⇄ remote:

1. **Ownership** — claim / purge as above.
2. **Pull + merge** (when `pull: true`) — streak docs and the window's day docs from Firestore are merged into local (improve-only / max / later-day-wins), restoring locks and quotas on a new device.
3. **Push** — merged local state is written to the user's private Firestore docs when it differs from what was last pushed.
4. **Leaderboard** — for each cleared day in the window whose time hasn't been confirmed on the leaderboard, call `submitBestTime(..., dayId: <the clear's day>)`.

Local "last pushed" markers make repeated runs cheap (no writes when nothing changed).

Triggers (`ProgressSyncLifecycle`, modeled on `AppOpenLifecycle`):
- app start (signed in) → full sync
- `AppLifecycleState.resumed` → full sync, throttled to once per 2 minutes
- sign-in (null → uid) → full sync, unthrottled
- local progress change (score / streak / hint write) → push-only sync, debounced 2 s
- `ensureSignedInForPlay` after a successful sign-in awaits a full sync (3 s timeout) so a reinstalled user cannot replay a day they already cleared
- after any sync that changed local data, Home reloads (stream `restored`)

Runs are serialized: a call while one is in flight marks "run again" and returns the in-flight future.

## Data model (Firestore)

Release paths (debug builds — `kDebugMode` — use the `_debug` twins, mirroring `leaderboards_debug`; a helper `progressCollections({bool? isDebugMode})` returns the names):

### `users/{uid}/game_days/{gameId}_{playId}` (debug: `game_days_debug`)

| Field | Type | Notes |
|---|---|---|
| `gameId` | string | `zip` \| `path_words` \| `sudoku` |
| `playId` | string | `YYYYMMDD` (release) or `YYYYMMDDHHmm` (debug minute period) |
| `timeSeconds` | int ≥ 0 | optional; present ⇔ cleared. Best (min) time |
| `points` | int ≥ 0 | optional; best (max) points |
| `usedHints` | bool | optional (present when cleared) |
| `hadMistakes` | bool | optional (present when cleared) |
| `flagsKnown` | bool | optional; false for legacy-derived flags |
| `hintsUsed` | int 0..50 | hint quota consumed that day |
| `clearedAt` | timestamp | optional; first time the clear was pushed |
| `updatedAt` | timestamp | `== request.time` |

### `users/{uid}/game_streaks/{gameId}` (debug: `game_streaks_debug`)

| Field | Type |
|---|---|
| `current` | int ≥ 0 |
| `longest` | int ≥ 0 |
| `lastClearedDateId` | string `YYYYMMDD` or null |
| `freezeAvailable` | bool |
| `updatedAt` | timestamp `== request.time` |

Writes use `set(..., SetOptions(merge: true))` — **not transactions** — so they are queued by Firestore offline persistence.

## Merge rules (pure functions, `lib/domain/logic/progress_merge.dart`)

- **Day:** `timeSeconds` = min of non-null; `points` = max of non-null; flags come from the side whose time won (ties prefer `flagsKnown == true`, then local); `hintsUsed` = max; `clearedAt` = earliest non-null.
- **Streak:** winner = later `lastClearedDateId` (null is oldest); tie → higher `current`, then local. Result = winner's `current`, `lastClearedDateId`, `freezeAvailable`; `longest` = max(local.longest, remote.longest, result.current).
- **Mode keys:** zip `zip_daily_<playId>`, path words `path_words_<playId>`, sudoku `sudoku_<playId>` (must equal what blocs / `HomeCubit` use).
- **Leaderboard day for a playId:** first 8 chars → `YYYY-MM-DD`.
- **Window:** `[PlayPeriod.id(now - period), PlayPeriod.id(now)]` for `DevFlags.playPeriod`.

## Flutter app

### Domain (pure Dart)
- `domain/entities/game_day_record.dart` — `GameDayRecord` (fields as the table; `bool get cleared`), value equality.
- `domain/entities/clear_meta.dart` — `ClearMeta {bool usedHints, bool hadMistakes}` stored locally alongside the best time.
- `domain/repositories/progress_remote_repository.dart` — `fetchDay`, `saveDay`, `fetchStreak`, `saveStreak` (all take `uid`).
- `domain/repositories/progress_local_repository.dart` — owner uid get/set, `purgeUserProgress()`, pushed-signature markers get/set.
- `ScoreRepository` gains: optional `usedHints` / `hadMistakes` on `submitScore` (stored as `ClearMeta` when this submit sets a new best time or there is no meta yet), `ClearMeta? getClearMeta(modeKey)`, `Future<bool> restoreBest({modeKey, points, timeSeconds, ClearMeta? meta})` (improve-only; returns whether local changed).
- `HintQuotaRepository` gains `int usedFor(gameId, playId)` and `Future<bool> restoreUsed(gameId, playId, used)` (max).
- `LeaderboardRepository.submitBestTime` / `SubmitLeaderboardTime` gain optional `String? dayId` (default `leaderboardDayId()`).
- `domain/usecases/sync_progress.dart` — `SyncProgress` as described; returns `SyncProgressResult {bool localChanged, int failures}`.

### Data
- `data/repositories/progress_remote_repository_impl.dart` — Firestore impl, `FirebaseBootstrap.isReady` guard, public top-level mappers `gameDayToFirestore` / `gameDayFromFirestore` / `streakToFirestore` / `streakFromFirestore` (unit-tested like `mapLeaderboardRows`).
- `data/repositories/progress_local_repository_impl.dart` — prefs keys: `progress_owner_uid`, `sync_day_<gameId>_<playId>`, `sync_lb_<gameId>_<playId>`, `sync_streak_<gameId>`. `purgeUserProgress` removes every key with prefix `best_`, `clear_meta_`, `streak_`, `hints_used_`, `in_progress_`, `sync_`.
- Score / streak / hint-quota impls accept an optional `void Function()? onChanged` called after each write (DI wires it to the lifecycle's debounced push).
- `ProfileRepositoryImpl._denormalizeLeaderboards` also refreshes Sudoku rows (was zip + path words only).

### Blocs (Zip, Path Words, Sudoku)
- Pass `usedHints` / `hadMistakes` into `submitScore`.
- Pass `dayId: leaderboardDayId(state.day)` to `submitLeaderboardTime` (fixes runs finished after midnight landing on the wrong day).

### Lifecycle / UI
- `core/lifecycle/progress_sync_lifecycle.dart` — triggers above; started next to `AppOpenLifecycle` in `app.dart`.
- `ensureSignedInForPlay` awaits sync after sign-in (timeout 3 s, errors ignored).
- Home reloads when `restored` fires.

## Firestore rules

New owner-only match blocks for `users/{uid}/game_days/{dayKey}`, `users/{uid}/game_streaks/{gameId}` and both `_debug` twins: read/create/update only by owner, delete false, strict key whitelist and type checks per the tables, `dayKey == gameId + '_' + playId`, `playId` matches `^[0-9]{8}([0-9]{4})?$`, `updatedAt == request.time`. **Every field the client writes must be in the whitelist** (lesson from the `currentStreak` incident) — a test asserts the client payload keys equal the documented key set.

Rules must be deployed **before** the build ships.

## Testing

- Pure merge / key / window / legacy-flag functions — exhaustive unit tests.
- Repo impls — prefs-backed tests (`setMockInitialValues`), Firestore mappers via plain maps, not-ready guards.
- `SyncProgress` — mocktail repos: signed out no-op; legacy claim; account switch purge; restore from remote; push only on change; leaderboard backfill with dayId from playId and legacy flags; marker prevents repeat; failure → no marker + reported; serialization.
- Blocs — completion passes flags + dayId.
- Lifecycle — start / resume throttle / sign-in / debounce.
- Rules — compile via `firebase deploy --only firestore:rules --dry-run`; payload-key test.

## Docs

- `FIREBASE.md` data paths + rules checklist + data-safety fields.
- `docs/privacy/index.html` — progress synced privately to the account; leaderboard fields incl. Sudoku, flags, streak; deletion scope; date.
- `play/data_safety.csv` — `PSL_USER_INTERACTION` purpose `PSL_APP_FUNCTIONALITY` true.

## Out of scope

- Syncing in-progress drafts, tutorial / SFX / notification flags.
- Re-posting daily boards older than the window.
- In-app account deletion.
