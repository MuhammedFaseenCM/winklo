# Levels Leaderboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A per-game, all-time Levels board ranked by stars (then fewer levels cleared, then lower total best time), fed only by level clears the leaderboard Worker has checked.

**Architecture:** The app posts each level clear to a new Worker route `POST /v1/level-clear`. The Worker checks the Zip path against the published level, works out the stars itself, merges into a private `leaderboards/{game}/level_records/{uid}` doc and rewrites the public row `leaderboards/{game}/levels/{uid}` from it. The app reads the row like the other boards through a new `LeaderboardPeriod.levels`. Unsent clears wait in a local per-account store and the sync pass resends them.

**Tech Stack:** Flutter (Cubit, freezed, `bloc_test`, `mocktail`), Firestore, Cloudflare Worker in TypeScript (vitest), Firestore rules tests (vitest + emulator).

**Spec:** `docs/superpowers/specs/2026-11-18-levels-leaderboard-design.md`

**Branch:** `master` has unrelated uncommitted work (level goals). Create `feat/levels-leaderboard` in a worktree (superpowers:using-git-worktrees) before Task 1.

## Global Constraints

- Ranking: `stars` desc, `levelsCleared` asc, `timeSeconds` asc, then `updatedAt` asc. Rows tie (share a dense rank) when stars, levelsCleared and timeSeconds are all equal.
- Board row fields, exactly: `stars`, `levelsCleared`, `timeSeconds`, `displayName`, `photoUrl`, `avatarId`, `updatedAt`.
- Records doc fields, exactly: `levels` (map `levelId → {stars, bestSeconds}`), `updatedAt`.
- No client writes the score fields of either doc. Only the Worker writes them, and only on the release root `leaderboards`.
- The client never sends stars. The Worker computes them with `starsFor(usedHints, seconds, targetSeconds)`, ported to TS exactly as `lib/domain/logic/level_stars.dart`.
- Level games list: `['zip']`. Level id pattern: `^{gameId}_(\d+)_(\d+)$`, and the world doc is `level_worlds/{gameId}_{group1}`.
- Everyone starts at zero: no import from `level_progress`.
- No direct-write fallback for level clears. Debug builds (no Worker, `leaderboards_debug` root) send nothing.
- All user-facing copy goes through `AppStrings`, in English (`app_text_en.dart`) and Malayalam (`app_text_ml.dart`).
- Level runs stay `isDaily == false`. Nothing here touches daily boards, streaks or `daily_activity`.

## Review Focus

1. **Account switch between clear and send:** a pending clear made as account A must never post as account B. The pending store is keyed by uid and posts with `expectedUid` (tests in Task 5 and Task 6).
2. **The same clear sent twice** (sync resend after a lost response): the second send must change nothing and return `improved: false` (test in Task 3).
3. **Debug builds:** with no Worker client or on `leaderboards_debug`, `submitLevelClear` must neither send nor keep anything pending (test in Task 5).
4. **Better offline replay replaces worse:** when two unsent clears of one level are waiting, the better one (stars, then time) is kept, and it survives an app restart (test in Task 5).
5. **Ties on the phone:** league boards ranked on the phone must tie only when all three keys match, and must order a 3★×1 player above a 1★×3 player with equal stars (tests in Task 7).

---

### Task 1: Stars on the Worker, pinned to the app's

**Files:**
- Create: `workers/leaderboard/src/level_stars.ts`
- Create: `workers/leaderboard/src/fixtures/level_stars.json`
- Test: `workers/leaderboard/src/level_stars.test.ts`
- Test: `test/firestore/level_stars_fixture_test.dart`

**Interfaces:**
- Produces: `export function starsFor(usedHints: boolean, seconds: number, targetSeconds: number | null | undefined): 1 | 2 | 3`

- [ ] **Step 1: Write the shared fixture.** `level_stars.json` is `{"_comment": "...both sides run this table...", "cases": [{usedHints, seconds, targetSeconds, stars}, …]}`. It must include these cases: `(false, 20, 20) → 3`, `(false, 21, 20) → 2`, `(true, 10, 20) → 2`, `(true, 30, 20) → 1`, `(false, 10, null) → 2`, `(false, 10, 0) → 2`, `(false, 10, -5) → 2`, `(false, 0, 20) → 2`.
- [ ] **Step 2: Write both failing tests.** `level_stars.test.ts` iterates `cases` and expects `starsFor(...)` to equal `stars`. `level_stars_fixture_test.dart` reads the JSON file (the same way `leaderboard_proof_fixture_test.dart` reads `app_proofs.json`) and checks Dart's `starsFor` for each case.
- [ ] **Step 3: Run them.** Run `cd workers/leaderboard && npx vitest run src/level_stars.test.ts`. Expected: FAIL (module missing). Run `flutter test test/firestore/level_stars_fixture_test.dart`. Expected: PASS, because the Dart side already exists.
- [ ] **Step 4: Implement `starsFor`** in `level_stars.ts` with the same rule as the Dart version.
- [ ] **Step 5: Run both again.** Expected: PASS.
- [ ] **Step 6: Commit** with message `feat(leaderboard): Worker stars for level clears, pinned to the app's table`.

### Task 2: Level records merge and the board row (pure)

**Files:**
- Create: `workers/leaderboard/src/level_board.ts`
- Modify: `workers/leaderboard/src/limits.ts` (add `LEVEL_GAMES`, `LEVEL_BOARD_FIELDS`, `LEVEL_RECORD_FIELDS`)
- Test: `workers/leaderboard/src/level_board.test.ts`

**Interfaces:**
- Consumes: `starsFor` (Task 1), `cleanIdentity`/`Identity` (`identity.ts`), `checkZipProof`/`parseZipPuzzle` (`proofs.ts`), `StoredDoc`/`CommitWrite` (`firestore.ts`).
- Produces:
  - `export const LEVEL_GAMES = ['zip'] as const; export type LevelGameId`
  - `export type LevelClear = { gameId: LevelGameId; levelId: string; worldOrder: number; timeSeconds: number; usedHints: boolean; proof: unknown; identity: Identity }`
  - `export function parseLevelClearBody(body: unknown): LevelClear | null`
  - `export type LevelRecord = { stars: number; bestSeconds: number }`
  - `export function findLevel(worldDoc: Record<string, unknown> | null, levelId: string): { puzzle: ZipPuzzle; targetSeconds: number | null } | null`. Returns null when the doc is missing, `published !== true`, the level isn't in `levels`, or the board doesn't parse.
  - `export function mergeLevelRecord(records: Record<string, LevelRecord>, levelId: string, run: LevelRecord): { records: Record<string, LevelRecord>; improved: boolean }`. Takes the higher stars and the lower bestSeconds, each separately. It ignores stored entries that aren't valid (stars outside 1–3, bestSeconds < 1).
  - `export function levelBoardTotals(records: Record<string, LevelRecord>): { stars: number; levelsCleared: number; timeSeconds: number }`

- [ ] **Step 1: Write failing tests:**
  - `parseLevelClearBody`: accepts a valid body. Rejects a game outside `LEVEL_GAMES`, a level id not matching `^zip_(\d+)_(\d+)$`, `timeSeconds` that isn't a whole number, and `usedHints` that isn't a boolean. `worldOrder` is parsed from the id (`zip_3_07` → 3).
  - `findLevel`: null for an unpublished world, a missing level and a missing doc. Returns the puzzle and `targetSeconds` for a published one (use a world fixture built from `app_proofs.json`'s zip puzzle wrapped as `{published: true, levels: [{id, …puzzle, targetSeconds: 30}]}`).
  - `mergeLevelRecord`: first clear → improved. Same run again → not improved and records unchanged. `{3, 40}` then `{2, 20}` → `{3, 20}` and improved. `{1, 10}` then `{3, 50}` → `{3, 10}`.
  - `levelBoardTotals`: `{a: {3, 10}, b: {2, 25}}` → `{stars: 5, levelsCleared: 2, timeSeconds: 35}`, and `{}` → all zeros.
- [ ] **Step 2: Run** `npx vitest run src/level_board.test.ts`. Expected: FAIL.
- [ ] **Step 3: Implement** in `level_board.ts` and add the constants to `limits.ts`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(leaderboard): level records merge and board totals`.

### Task 3: `POST /v1/level-clear`

**Files:**
- Create: `workers/leaderboard/src/level_submit.ts`
- Modify: `workers/leaderboard/src/index.ts` (route both paths through the shared auth and body handling)
- Test: `workers/leaderboard/src/level_submit.test.ts`, `workers/leaderboard/src/index.test.ts`

**Interfaces:**
- Consumes: Task 2; `batchGet`, `commit`, `ContentionError`, `encodeFields` (`firestore.ts`); `SubmitDeps` (`submit.ts`); `MIN_SECONDS`, `MAX_SECONDS`, `LEADERBOARD_ROOT`.
- Produces: `export async function handleLevelClear(deps: SubmitDeps, uid: string, rawBody: unknown): Promise<SubmitResponse>`. On 200 the body is `{accepted: true, improved: boolean}`. Errors: 400 `bad_request`; 422 `too_fast`, `too_slow`, `not_live` (missing or unpublished world, or unknown level), `bad_proof`; 503 `unavailable` or `busy`. Paths: `{LEADERBOARD_ROOT}/{game}/level_records/{uid}`, `{LEADERBOARD_ROOT}/{game}/levels/{uid}`, `level_worlds/{game}_{worldOrder}`.

- [ ] **Step 1: Write failing tests** with fake `batchGet`/`commit`, following `submit.test.ts`:
  - A valid clear with no docs writes records and a row `{stars: 3, levelsCleared: 1, timeSeconds: 12, displayName…, updatedAt}`, both with `exists: false` preconditions.
  - `usedHints: true` at the same time writes `stars: 2`. A client `stars` field in the body is ignored.
  - **Sending the identical clear again** (stored docs now hold it) makes no commit and returns `{accepted: true, improved: false}` (Review Focus 2).
  - A worse run makes no commit. A faster run with fewer stars updates `bestSeconds` only and recomputes `timeSeconds`.
  - An unpublished world, an unknown level and a missing world doc → 422 `not_live`. A wrong path → 422 `bad_proof`. `timeSeconds: 0` → `too_fast`. `86_401` → `too_slow`.
  - Contention once → re-read and success. Contention twice → 503 `busy`.
  - `index.test.ts`: `POST /v1/level-clear` without a token → 401, and with a token it reaches `handleLevelClear`. `POST /v1/submit` still reaches `handleSubmit`.
- [ ] **Step 2: Run** `npx vitest run`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** `handleLevelClear`. Do one `batchGet` of the world doc, records and row. Check the times, then `findLevel`, then `checkZipProof` (non-ok → its code, as `/v1/submit` does). Compute stars from the level's `targetSeconds`, then merge. If nothing improved, return with no write. Otherwise commit records plus the row, with `updateTime` preconditions (`exists: false` when absent) and the `/v1/submit` single-retry loop. In `index.ts`, pull the token, size and JSON handling out of `route` so both paths share it.
- [ ] **Step 4: Run** `npx vitest run && npx tsc --noEmit`. Expected: all PASS.
- [ ] **Step 5: Commit** with message `feat(leaderboard): POST /v1/level-clear checks a level clear and writes the stars board`.

### Task 4: Rules, index, account deletion

**Files:**
- Modify: `firestore/firestore.rules` (next to the weekly match)
- Modify: `firestore/firestore.indexes.json`
- Modify: `workers/account-deletion/src/firestore_wipe.ts` (and its `paths.ts` if paths live there)
- Test: `firestore/rules_test/leaderboards.test.ts`, `workers/account-deletion/src/firestore_wipe.test.ts`

**Interfaces:**
- Produces: the Firestore paths the app reads in Tasks 7 and 9.

- [ ] **Step 1: Write failing rules tests:**
  - A signed-in player can read `leaderboards/zip/levels/{anyUid}`. An owner can't create or update `stars`, `levelsCleared` or `timeSeconds` on their own row.
  - An owner's `profileOnlyLeaderboardUpdate` (name, photo or avatar only) on an existing row is allowed. Delete is denied.
  - `leaderboards/zip/level_records/{uid}`: the owner can read and others can't, and all writes are denied.
  - Both paths reject a gameId outside the valid games.
- [ ] **Step 2: Write a failing wipe test:** `collectUserDocNames` includes `leaderboards/{game}/levels/{uid}` and `leaderboards/{game}/level_records/{uid}` for each game in `LEADERBOARD_GAMES`, on the release root only (like `WEEKLY_ROOTS`).
- [ ] **Step 3: Run** `cd firestore/rules_test && npm test` and `cd workers/account-deletion && npx vitest run`. Expected: FAIL.
- [ ] **Step 4: Implement.** Add the two `match` blocks (`allow read: if validGame(gameId)` for `levels`, owner read for `level_records`, profile-only update on `levels`, every other write `false`). Add the index `levels`: `stars DESC, levelsCleared ASC, timeSeconds ASC, updatedAt ASC` (collection scope). Add the wipe paths.
- [ ] **Step 5: Run again.** Expected: PASS.
- [ ] **Step 6: Commit** with message `feat(leaderboard): rules, index and deletion wipe for the levels board`.

### Task 5: App sending — client, repository, pending store

**Files:**
- Modify: `lib/data/clients/leaderboard/leaderboard_submit_client.dart`, `http_leaderboard_submit_client.dart` (add `submitLevelClear`, path `/v1/level-clear`)
- Modify: `lib/domain/repositories/leaderboard_repository.dart`, `lib/data/repositories/leaderboard_repository_impl.dart`
- Create: `lib/domain/entities/pending_level_clear.dart`
- Create: `lib/domain/repositories/pending_level_clear_repository.dart`, `lib/data/repositories/pending_level_clear_repository_impl.dart`
- Modify: `lib/core/di/app_repositories.dart`
- Test: `test/data/repositories/leaderboard_repository_level_clear_test.dart`, `test/data/repositories/pending_level_clear_repository_impl_test.dart`, `test/data/clients/http_leaderboard_submit_client_test.dart`

**Interfaces:**
- Consumes: `ZipLeaderboardProof` (`leaderboard_proof.dart`), `LeaderboardSubmitRefused`.
- Produces:
  - `LeaderboardSubmitClient.submitLevelClear({required String idToken, required Map<String, Object?> body}) → Future<LeaderboardSubmitResult>`. It throws the same `Rejected`/`Unavailable` as `submit`, and the codes set gains `too_slow`.
  - `LeaderboardRepository.submitLevelClear({required String gameId, required String levelId, required int timeSeconds, required bool usedHints, required LeaderboardProof proof, required String expectedUid, ({String displayName, String? photoUrl, String? avatarId})? identity}) → Future<LevelClearSubmitOutcome>`
  - `enum LevelClearSubmitOutcome { sent, unavailable, notSent }`. `notSent` means debug, no client or not signed in. On a 4xx it throws `LeaderboardSubmitRefused`.
  - `class PendingLevelClear { String levelId; int stars; int timeSeconds; bool usedHints; ZipLeaderboardProof proof; toJson/fromJson; bool betterThan(PendingLevelClear other) }`. `stars` is the app's own local count, used only to choose which run to keep.
  - `abstract class PendingLevelClearRepository { List<PendingLevelClear> pending(String uid, String game); Future<void> keep(String uid, String game, PendingLevelClear clear); Future<void> drop(String uid, String game, String levelId); }`. `keep` replaces an existing entry for the level only when the new one is `betterThan` it. Storage is SharedPreferences, key `pending_level_clears_{uid}_{game}`.

- [ ] **Step 1: Write failing tests:**
  - HTTP client: posts to `{base}/v1/level-clear` with a Bearer token. 422 `{error: 'bad_proof'}` → `Rejected(422, 'bad_proof')`. 503, a timeout or a **404** (an app shipped before the Worker route) → `Unavailable`, so the clear stays pending instead of being dropped.
  - Repository: release root plus a client posts the body `{gameId, levelId, timeSeconds, usedHints, proof: {path}, identity}` and returns `sent`. Unavailable → `unavailable`. 422 → throws `LeaderboardSubmitRefused('bad_proof')`. A stale token is retried once (as `_postToWorker`).
  - **A debug root, or no client, returns `notSent` and never calls the client** (Review Focus 3). An `expectedUid` that differs from the current user throws before posting (Review Focus 1).
  - Pending store: `keep` of `{3★, 40s}` then `{2★, 10s}` keeps the 3★ run; `{2★, 40s}` then `{2★, 30s}` keeps the 30s run (Review Focus 4). Entries survive a new instance over the same prefs (restart). Entries under uid A are not visible under uid B. `drop` removes one level.
- [ ] **Step 2: Run** `flutter test test/data`. Expected: FAIL.
- [ ] **Step 3: Implement.** Reuse `_postToWorker` by giving it the client call to make, so both endpoints share the token retry. Register `PendingLevelClearRepository` in `app_repositories.dart`.
- [ ] **Step 4: Run again.** Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(levels): send level clears to the Worker; keep unsent ones per account`.

### Task 6: `SubmitLevelClear`, the Zip hook and the sync resend

**Files:**
- Create: `lib/domain/usecases/submit_level_clear.dart`
- Modify: `lib/features/zip/bloc/zip_bloc.dart` (`_finishLevel`), its DI construction site
- Modify: `lib/domain/usecases/sync_progress.dart`
- Modify: `lib/domain/repositories/analytics_repository.dart` + impl (`logLevelBoardSubmit`)
- Test: `test/domain/usecases/submit_level_clear_test.dart`, `test/features/zip/bloc/zip_bloc_level_test.dart`, `test/domain/usecases/sync_progress_test.dart`

**Interfaces:**
- Consumes: Task 5; `AuthRepository` (current uid and identity, as `SubmitLeaderboardTime` gets them).
- Produces:
  - `SubmitLevelClear.call({required String game, required String levelId, required int stars, required int timeSeconds, required bool usedHints, required ZipLeaderboardProof proof}) → Future<void>`. It never throws to the caller.
  - `SubmitLevelClear.resendPending(String game) → Future<void>`, used by SyncProgress.
  - `AnalyticsRepository.logLevelBoardSubmit({required String levelId, required bool accepted, required bool improved, String? code})`

- [ ] **Step 1: Write failing tests:**
  - Signed out does nothing. Signed in: it calls `keep` first, then `submitLevelClear` with `expectedUid` set to the current uid. `sent` → `drop`. `unavailable` → stays pending. `LeaderboardSubmitRefused` → `drop` plus a client-error report. `notSent` → `drop` (debug: nothing should pile up).
  - Each outcome logs `level_board_submit` with the right fields.
  - `resendPending` posts each pending clear for the current uid only. An account switch mid-loop stops it (Review Focus 1).
  - ZipBloc level mode: after `recordLevelClear`, `submitLevelClear` gets the run's stars (`clear.runStars`), `elapsed`, `usedHintsThisRun` and `ZipLeaderboardProof(state.path)`. Results are emitted without waiting for the network: the submit is fire-and-forget (`unawaited`).
  - SyncProgress: its pass calls `resendPending(GameIds.zip)` once, after level progress sync, inside the same timeout and account guards as the daily board resend.
- [ ] **Step 2: Run** the three test files. Expected: FAIL.
- [ ] **Step 3: Implement.** Make `SubmitLevelClear` an optional ZipBloc dependency like `recordLevelClear`, and provide it where `RecordLevelClear` is provided.
- [ ] **Step 4: Run** `flutter test test/domain test/features/zip`. Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(levels): every level clear goes to the board; sync resends unsent ones`.

### Task 7: Reading the board

**Files:**
- Modify: `lib/domain/entities/leaderboard_period.dart` (add `levels`)
- Modify: `lib/domain/entities/leaderboard_entry.dart` (add `int? stars`, `int? levelsCleared`)
- Modify: `lib/domain/leaderboard_ranking.dart`
- Modify: `lib/data/repositories/leaderboard_repository_impl.dart` (`_boardCollection`, query ordering, entry mapping, `watchMembersBoard`)
- Modify: every `switch` on `LeaderboardPeriod` the analyzer flags (`board_calendar.dart`, `board_layout.dart`, `leaderboard_screen.dart`, `leaderboard_board_sheet.dart`, `leaderboard_board_view.dart`, `leaderboard_podium.dart`, `leaderboard_table.dart`, `player_card_sheet.dart`). Here only make them compile with sensible levels behaviour; the UI comes in Task 8.
- Modify: `test/firestore/leaderboard_fair_play_pins_test.dart` (pin `LEVEL_BOARD_FIELDS` against the app's field list)
- Test: `test/domain/leaderboard_ranking_test.dart`, `test/data/repositories/leaderboard_repository_impl_test.dart`, `test/features/leaderboard/cubit/leaderboard_cubit_test.dart`

**Interfaces:**
- Produces: `LeaderboardPeriod.levels`, and `LeaderboardEntry.stars` / `levelsCleared` (non-null on levels rows; `timeSeconds` is the total best time).

- [ ] **Step 1: Write failing tests:**
  - `rankLeaderboardEntries(_, levels)`: `[A 9★ 3lv 60s, B 9★ 5lv 40s, C 12★ 6lv 99s]` → C=1, A=2, B=3 (Review Focus 5). Two rows with `9★ 3lv 60s` share a rank, while `9★ 3lv 61s` gets the next one.
  - Repository: `watchBoard(levels)` queries `leaderboards/zip/levels` ordered `stars desc, levelsCleared asc, timeSeconds asc, updatedAt asc`, limit 50, and maps the fields. `watchMembersBoard(levels)` reads members' rows from the same collection and ranks them on the phone. A debug root returns an empty board.
  - Cubit: `selectBoard(LeaderboardPeriod.levels)` resubscribes. `showAllTimeLeaderboard == false` doesn't hide levels.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement**, then `dart run build_runner build --delete-conflicting-outputs` if any freezed state changed.
- [ ] **Step 4: Run** `flutter analyze && flutter test test/domain test/data test/features/leaderboard test/firestore`. Expected: no issues, PASS.
- [ ] **Step 5: Commit** with message `feat(leaderboard): Levels period reads the stars board`.

### Task 8: Board tab UI

**Files:**
- Modify: `lib/features/leaderboard/view/widgets/leaderboard_board_sheet.dart` (a `Levels` option after All time, `AppIcons.levels`)
- Modify: `leaderboard_table.dart`, `leaderboard_row.dart`, `leaderboard_podium.dart`, `leaderboard_board_view.dart`, `leaderboard_screen.dart` (`_RouteGameSync` reads `board=levels`)
- Modify: `lib/core/strings/app_strings.dart`, `app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`
- Test: `test/features/leaderboard/view/leaderboard_levels_board_test.dart`, `test/core/strings/app_text_test.dart`

**Interfaces:**
- Consumes: Task 7.
- Produces: the route `/leaderboard?game=zip&board=levels`, which selects Zip and the Levels period even when the tab is already alive. Task 9 links to it.

Copy (English; give Malayalam equivalents in `app_text_ml.dart`):
- `leaderboardBoardLevels` = "Levels"
- `leaderboardLevelsStars(n)` = "$n★" with a semantics label "$n stars"
- `leaderboardLevelsDetail(levels, time)` = "$levels levels · $time" (time formatted as on the other boards)
- `leaderboardLevelsEmpty` = "No one's on the Levels board yet" and the button `leaderboardLevelsPlay` = "Play levels" (goes to `/levels`)
- `leaderboardLevelsJoin` = "Clear a level to join"
- `leaderboardLevelsReplay` = "Replay a level to count your stars" (pinned row when the player isn't on the board but their local Zip progress has ≥ 1 star)

- [ ] **Step 1: Write failing widget tests:**
  - The board sheet shows Levels, and picking it calls `selectBoard(levels)`.
  - A levels row shows "92★" as the main figure and "40 levels · 42:11" as the second line, with no hints or streak chips. The podium shows stars.
  - The empty board shows the empty copy, and Play levels navigates to `/levels`.
  - A signed-in player not on the board sees "Clear a level to join", or the replay line when their local progress has stars.
  - `go('/leaderboard?game=zip&board=levels')` on an alive tab switches to Levels.
  - `app_text_test.dart` covers the new keys in both languages.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.** Reuse the existing row and podium widgets and switch on `period == levels` for the figures. Don't add new widget families.
- [ ] **Step 4: Run** `flutter test test/features/leaderboard test/core/strings`. Expected: PASS.
- [ ] **Step 5: Commit** with message `feat(leaderboard): Levels board on the Board tab`.

### Task 9: Levels tab — header link and the "not on the board yet" line

**Files:**
- Modify: `lib/features/levels/view/levels_screen.dart` (`_Header`: the star chip becomes a button with a chevron)
- Modify: `lib/features/levels/view/widgets/level_sheet.dart`
- Modify: `lib/features/levels/cubit/level_map_cubit.dart` (+ state)
- Modify: `lib/domain/repositories/leaderboard_repository.dart` + impl: `Future<Set<String>?> myBoardLevelIds(String gameId)`
- Modify: strings files
- Test: `test/features/levels/view/levels_screen_test.dart`, `test/features/levels/view/level_sheet_test.dart`, `test/features/levels/cubit/level_map_cubit_test.dart`, `test/data/repositories/leaderboard_repository_impl_test.dart`

**Interfaces:**
- Consumes: Task 8's route.
- Produces: `myBoardLevelIds` returns the ids in `level_records/{uid}.levels`. It returns null when signed out, on a debug root, or when the read fails, in which case the sheet shows no line. It reads server-first with a cache fallback, at most once per `LevelMapCubit` load.

Copy: `levelSheetNotOnBoard` = "Not on the board yet · replay to count". `levelsStarsToBoard` = semantics "Open the Levels leaderboard".

- [ ] **Step 1: Write failing tests:**
  - Tapping the header's star chip calls `context.go('/leaderboard?game=zip&board=levels')`.
  - The sheet for a cleared level not in `boardLevelIds` shows the line. A level that is in it, an uncleared level, and the null case show no line.
  - The cubit loads `boardLevelIds` once per load, a failure leaves it null and the map still shows, and it reloads after the progress `changes` that follow a clear.
  - The repo reads `leaderboards/zip/level_records/{uid}` and returns null on a debug root.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze && flutter test`. Expected: no issues, all PASS. Then hot-reload the running app (Dart MCP) and check the header link and the sheet line on a device or emulator.
- [ ] **Step 5: Commit** with message `feat(levels): star total opens the Levels board; sheet flags levels not on it yet`.

---

## Rollout notes (not tasks)

- Deploy order: rules and index (Task 4), then the Worker (`wrangler deploy`, Task 3), then the app release. An app that ships before the Worker gets 404s, which count as `unavailable`, so clears stay pending and nothing is lost.
- `firebase deploy --only firestore:indexes` must have finished building before the board is visible.
