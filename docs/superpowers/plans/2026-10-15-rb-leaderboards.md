# Leaderboards, leagues and fair play — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build area C of `docs/superpowers/specs/2026-10-15-roadmap-batch-design.md` on `feat/rb-leaderboards`: past days' boards, the player card, the weekly board, friends and private leagues, and fair play (a `workers/leaderboard` Worker, the app submitting through it with a fallback, the board hidden while paused, phase-1 rules), plus the account-deletion Worker changes.

**Architecture:** A new Cloudflare Worker (`winklo-leaderboard`) verifies the Firebase ID token, checks the day is live, the time is above the game's minimum and the proof solves the stored puzzle, then writes the daily, all-time and weekly entries in one Firestore `:commit` with `updateTime` preconditions. The app posts to it through a `LeaderboardSubmitClient` and falls back to today's direct writes on a network error or a 5xx. Leagues are plain Firestore docs guarded by rules; a league board is a `whereIn` on the members' entry ids, ranked on the phone with the same rules as the server boards.

**Tech stack:** Flutter (Cubit, freezed, go_router, cloud_firestore, http), `bloc_test` + `mocktail`; Cloudflare Workers (TypeScript, `jose`, vitest); Firestore rules (tested with `@firebase/rules-unit-testing` on the emulator).

---

## Decisions taken while planning (record in the final report)

- **Proof-less submits still write directly.** The Results "sign in to save this time" claim and the sync backfill have no proof for Sudoku and Path Words; they keep the direct write (and stop working in phase 2). Zip's sync backfill rebuilds its proof from the saved board; the Results claim carries the bloc's proof through `ResultsArgs`.
- **Times under the game's minimum are skipped on the phone** (no write, no error), because both the rules and the Worker would refuse them.
- **Sudoku also tries `sudoku_levels/sudoku_{YYYYMMDD}`** when `daily_{YYYYMMDD}` is missing, the same fallback the app's loader uses.
- **Phase-1 daily checks apply to the release root only.** `leaderboards_debug` stays as it is, since debug builds use minute periods and fast test clears.
- **Puzzle collections: `list` becomes admin-only.** A list query would otherwise return a future daily and undo the per-document block. No app code lists them (`FetchZipLevels` is registered but unused).
- **The owner can't leave a league;** they delete it. Members stay 1–30, so the owner is always a member.
- **Identity-only refreshes stay allowed in phase 2**, but may no longer change `currentStreak` once `directLeaderboardWritesAllowed()` is false (renames keep reaching the board).
- **Member names on the league screen** come from the members' all-time entries (the league doc stores uids only, per the spec).

## File map

Worker `workers/leaderboard/` (new):

| File | Responsibility |
|---|---|
| `package.json`, `tsconfig.json`, `wrangler.toml`, `vitest.config.ts` | Same shape as the other Workers; `FIREBASE_PROJECT_ID` var, `FIREBASE_SERVICE_ACCOUNT_JSON` secret |
| `src/limits.ts` | `GAMES`, `MIN_SECONDS`, `MAX_SECONDS`, `PUZZLE_COLLECTIONS`, `ENTRY_FIELDS`, `WEEKLY_FIELDS` (pinned by `test/firestore`) |
| `src/days.ts` | `parseDayId`, `isDayLive(dayId, now)` (10:00 UTC the day before to 12:00 UTC the day after), `isoWeekId(dayId)` |
| `src/identity.ts` | `cleanDisplayName`, `cleanPhotoUrl`, `cleanAvatarId` (same limits as `lib/data/leaderboard_identity.dart`) |
| `src/proofs.ts` | Puzzle parsers (`parseZipPuzzle`, `parseSudokuPuzzle`, `parsePathWordsPuzzle`) and `checkZipProof`, `checkSudokuProof`, `checkPathWordsProof` |
| `src/firestore.ts` | REST value encode/decode, `batchGet`, `commit` |
| `src/entries.ts` | Pure write planning: `planEntryWrite` (improve-only daily/all-time) and `planWeeklyWrite` |
| `src/submit.ts` | `parseSubmitBody`, `handleSubmit` (checks → reads → plan → commit, retry once) |
| `src/firebase_auth.ts`, `src/google_auth.ts` | Copied from `account-deletion` (token cached per isolate) |
| `src/index.ts` | Routing: `GET /v1/health`, `POST /v1/submit` |

App:

| File | Responsibility |
|---|---|
| `lib/domain/leaderboard_limits.dart` | `leaderboardMinSeconds`, `leaderboardMaxSeconds` |
| `lib/domain/iso_week.dart` | `isoWeekIdForDayId('yyyy-MM-dd')` → `yyyy-Www` |
| `lib/domain/entities/leaderboard_proof.dart` | `LeaderboardProof` (Zip path, Sudoku grid, Path Words strokes) with `toJson()` |
| `lib/domain/entities/leaderboard_period.dart` | add `weekly` |
| `lib/domain/entities/leaderboard_entry.dart` | add `daysCleared` (weekly) |
| `lib/domain/leaderboard_ranking.dart` | `rankDailyEntries`, `rankWeeklyEntries` (sort + dense rank on the phone) |
| `lib/domain/entities/league.dart`, `lib/domain/league_code.dart` | League value type; code alphabet, generator, normaliser, invite URL, name rules |
| `lib/domain/repositories/league_repository.dart` | League interface |
| `lib/domain/repositories/leaderboard_repository.dart` | `submitBestTime(proof:)`, `watchMembersBoard` |
| `lib/core/config/leaderboard_submit_config.dart` | `LEADERBOARD_SUBMIT_BASE_URL` |
| `lib/data/clients/leaderboard/leaderboard_submit_client.dart` | Interface + `LeaderboardSubmitRejected` / `LeaderboardSubmitUnavailable` |
| `lib/data/clients/leaderboard/http_leaderboard_submit_client.dart` | `POST /v1/submit` |
| `lib/data/repositories/leaderboard_repository_impl.dart` | Worker first, fallback, weekly + members boards |
| `lib/data/repositories/league_repository_impl.dart` | Firestore leagues |
| `lib/features/leaderboard/cubit/*` | `dayId`, scope (league), leagues list |
| `lib/features/leaderboard/view/widgets/leaderboard_day_strip.dart` | Today, Yesterday, then 12 dates |
| `lib/features/leaderboard/view/widgets/leaderboard_scope_bar.dart` | Everyone + my leagues + Leagues button |
| `lib/features/leaderboard/view/widgets/player_card_sheet.dart` | Tap-a-player sheet |
| `lib/features/leagues/cubit/*`, `lib/features/leagues/view/*` | Leagues list, create, join, detail, `/join/:code` |
| `lib/core/widgets/paused_board_cover.dart` | Covers the board while the run is paused |

Rules and tests: `firestore/firestore.rules`, `firestore/firestore.indexes.json`, `firestore/rules_test/` (new emulator suite), `test/firestore/*_test.dart` (pins).

---

## Task 1: Worker scaffold and limits

**Files:** create `workers/leaderboard/{package.json,tsconfig.json,wrangler.toml,vitest.config.ts,src/limits.ts,src/limits.test.ts}`; modify `.github/workflows/ci.yml` (matrix gets `leaderboard`).

- [ ] Copy `package.json`/`tsconfig.json` from `account-deletion` (name `winklo-leaderboard`, deps `jose`), `wrangler.toml` with `name = "winklo-leaderboard"`, `FIREBASE_PROJECT_ID = "brain-zip-app"`, no bindings. `npm install` to create the lockfile.
- [ ] Test `limits.test.ts`: `MIN_SECONDS` is `{zip: 10, path_words: 15, sudoku: 15}`, every game has a puzzle collection, `MAX_SECONDS === 86400`.
- [ ] Implement `limits.ts`; `npx tsc --noEmit -p . && npm test` pass. Commit `feat(leaderboard-worker): scaffold the Worker and its limits`.

## Task 2: Days and weeks

**Files:** `src/days.ts`, `src/days.test.ts`.

- [ ] Tests: `parseDayId('2026-02-30')` is null; `isDayLive('2026-10-15', …)` false at `2026-10-14T09:59:59Z`, true at `10:00:00Z`, true at `2026-10-16T11:59:59Z`, false at `12:00:00Z`; `isoWeekId` for `2026-01-01` → `2026-W01`, `2027-01-01` → `2026-W53`, `2024-12-30` → `2025-W01`, `2026-10-15` → `2026-W42`.
- [ ] Implement with `Date.UTC`. Commit.

## Task 3: Identity cleaning

**Files:** `src/identity.ts`, `src/identity.test.ts`.

- [ ] Tests mirror `test/data/leaderboard_identity_test.dart`: blank → `Player`; 41+ chars cut to 40 without splitting a surrogate pair; photo hosts (Google, R2 `/avatars`) kept, others null; avatar ids over 64 dropped.
- [ ] Implement; export `PHOTO_URL_PATTERN` (pinned against the rules). Commit.

## Task 4: Proof checks

**Files:** `src/proofs.ts`, `src/proofs.test.ts`.

- [ ] Parsers accept every cell form `Cell.fromJson` accepts (`[r,c]`, `{row,col}`, `"r,c"`), lowercase Path Words letters, and return null for broken docs.
- [ ] Zip tests: a serpentine solution passes; repeating a cell, skipping a cell, a diagonal step, a step through a wall, numbers out of order, not starting on 1, not ending on the last number, out-of-bounds cells and a short path all fail.
- [ ] Sudoku tests: the solution passes; one wrong digit, 35 cells, non-integers fail.
- [ ] Path Words tests: stored routes pass; an alternative route that spells the word and stays off other words passes; a stroke missing, a target traced twice, an unknown target, a gap between cells, a wrong word, two strokes sharing a cell, a blank cell, and an alternative route over another word's cells fail.
- [ ] Implement. Commit `feat(leaderboard-worker): check that proofs solve the stored puzzle`.

## Task 5: Firestore REST and write planning

**Files:** `src/firestore.ts`, `src/entries.ts`, tests for both.

- [ ] `decodeValue`/`encodeValue` round-trip ints, bools, null, strings, maps and arrays.
- [ ] `planEntryWrite(existing, submission)`: new doc → full write, `exists: false`; slower time → only `currentStreak` + identity, `updateTime` precondition; faster time → time, flags and `updatedAt` transform; identity omitted when unknown.
- [ ] `planWeeklyWrite(existing, dayId, seconds, identity)`: adds or improves `days[dayId]`, recomputes `daysCleared` and `totalSeconds`, moves `updatedAt` only when `days` changed.
- [ ] Commit.

## Task 6: Submit handler and routing

**Files:** `src/submit.ts`, `src/index.ts`, `src/firebase_auth.ts`, `src/google_auth.ts`, `src/submit.test.ts`, `src/index.test.ts`.

- [ ] `parseSubmitBody` tests: each field's type and range → `bad_request`; unknown game → `bad_request`.
- [ ] `handleSubmit` tests with a fake Firestore (fetch stub): not live → 422 `not_live`; under the minimum → 422 `too_fast`; missing puzzle → 422 `unknown_puzzle`; wrong proof → 422 `bad_proof`; streak capped at `game_streaks.current + 1`; one commit with three writes on the release root (`leaderboards/{game}/daily/{day}/entries/{uid}`, `all_time/{uid}`, `weekly/{week}/entries/{uid}`); a contention error retries once with fresh reads; a second contention → 503.
- [ ] `index.ts` tests: missing or bad token → 401; `GET /v1/health` → 200; other paths → 404.
- [ ] Commit `feat(leaderboard-worker): accept checked submissions and write the boards`.

## Task 7: Rules phase 1, indexes and pins

**Files:** `firestore/firestore.rules`, `firestore/firestore.indexes.json`, `firestore/rules_test/*` (new), `test/firestore/leaderboard_fair_play_pins_test.dart`, `lib/domain/leaderboard_limits.dart`.

Rules (added functions):

```
function directLeaderboardWritesAllowed() { return true; }
function minLeaderboardSeconds(gameId) { return {'zip': 10, 'path_words': 15, 'sudoku': 15}[gameId]; }
function leaderboardDayIsLive(dayId) { … 14 h before UTC midnight to 36 h after … }
function puzzleDocReadable(id) { return !id.matches('^daily_[0-9]{8}$') || isAdmin() || <live> ; }
```

- Release `daily` entries: create/improve need `directLeaderboardWritesAllowed()`, `timeSeconds >= minLeaderboardSeconds(gameId)`, a dashed `dayId` and `leaderboardDayIsLive(dayId)`; identity-only updates need the day pattern and live day.
- Release `all_time`: create/improve need `directLeaderboardWritesAllowed()` and the minimum.
- `leaderboards/{gameId}/weekly/{weekId}/entries/{uid}`: read if `validGame`, no writes.
- Puzzle collections: `get` if `puzzleDocReadable(id)`, `list` if `isAdmin()`.
- Leagues and codes as the spec says (Task 13 adds them; the rules test suite grows with it).
- Index: `entries` collection, `daysCleared` DESC, `totalSeconds` ASC, `updatedAt` ASC.

- [ ] Emulator suite (vitest + `@firebase/rules-unit-testing`), run with `firebase emulators:exec --only firestore "npm --prefix firestore/rules_test test"`: minimum time, malformed and not-live day ids, live-window edges, weekly read/no write, future daily refused, past daily and `level_01` readable, admin reads a future daily, list refused.
- [ ] Dart pins: rules `minLeaderboardSeconds` map == `leaderboardMinSeconds` == Worker `MIN_SECONDS`; Worker `ENTRY_FIELDS` == `leaderboardFirestoreKeys`; Worker `PHOTO_URL_PATTERN` == `leaderboardPhotoUrlPattern`; Worker name cap == `leaderboardDisplayNameMaxLength`; Worker `WEEKLY_FIELDS` == app `weeklyLeaderboardFields`; rules keep `directLeaderboardWritesAllowed()` returning `true`.
- [ ] Commit `feat(rules): fair-play phase 1 and the weekly board index`.

## Task 8: App submit client with fallback

**Files:** `lib/domain/entities/leaderboard_proof.dart`, `lib/core/config/leaderboard_submit_config.dart`, `lib/data/clients/leaderboard/*`, `lib/domain/repositories/leaderboard_repository.dart`, `lib/domain/usecases/submit_leaderboard_time.dart`, `lib/data/repositories/leaderboard_repository_impl.dart`, `lib/core/di/app_repositories.dart` (one line), tests under `test/data/` and `test/domain/`.

- [ ] `test/data/clients/http_leaderboard_submit_client_test.dart` (`MockClient` from `package:http/testing.dart`): 200 → result; 422 `{error: bad_proof}` → `LeaderboardSubmitRejected(422, 'bad_proof')`; 503 → `LeaderboardSubmitUnavailable`; `SocketException`/timeout → `LeaderboardSubmitUnavailable`; body carries the bearer token and JSON.
- [ ] `test/data/leaderboard_submit_body_test.dart`: `leaderboardSubmitBody(...)` matches the Worker's field list; proofs serialise as `{path: [[r,c]]}`, `{grid: [...]}`, `{strokes: [{targetId, cells}]}`.
- [ ] `test/data/repositories/leaderboard_repository_submit_test.dart`: release root + proof → Worker only; unavailable → direct writes (`fake_cloud_firestore` if present, otherwise a seam `directWrite` callback); rejected → reported non-fatal, `Failure`, no direct write; debug root → direct; no proof → direct; below the minimum → nothing written.
- [ ] Commit `feat(leaderboard): submit through the Worker with a direct-write fallback`.

## Task 9: Blocs pass proofs

**Files:** the three blocs (one argument each), `lib/features/results/results_args.dart` (+`leaderboardProof`), `results_screen.dart` and `mini_leaderboard_panel.dart` (pass it on), `lib/domain/usecases/sync_progress.dart` (Zip proof from the saved board).

- [ ] Bloc tests: each `submitLeaderboardTime` call carries the right proof (Zip path, Sudoku grid, Path Words completed strokes).
- [ ] Commit.

## Task 10: Past days

**Files:** `leaderboard_cubit.dart`/`leaderboard_state.dart` (`dayId`, `selectDay`), `widgets/leaderboard_day_strip.dart`, `leaderboard_screen.dart`.

- [ ] Cubit test: `selectDay('2026-10-13')` resubscribes with that day; switching to all-time ignores it; `leaderboardDayStrip(now)` gives 14 ids, today first.
- [ ] Widget test: the strip shows Today, Yesterday and a date; tapping a date reloads.
- [ ] Commit.

## Task 11: Player card

**Files:** `widgets/player_card_sheet.dart`, `leaderboard_screen.dart` (row `onTap`).

- [ ] Widget test: tapping a row opens a sheet with the name, time, Hint-free chip and streak; weekly rows show days and total.
- [ ] Commit.

## Task 12: Weekly tab

**Files:** `lib/domain/iso_week.dart`, `lib/domain/leaderboard_ranking.dart`, `leaderboard_period.dart`, `leaderboard_entry.dart`, repository `watchBoard` weekly branch + `mapWeeklyLeaderboardRows`, cubit, screen.

- [ ] Tests: ISO weeks match the Worker vectors; weekly rows rank by days desc, total asc, updatedAt asc with dense ranks; row label `5 days · 6:12`; debug root returns an empty board and the screen shows the note.
- [ ] Commit.

## Task 13: Leagues

**Files:** domain (`league.dart`, `league_code.dart`, `league_repository.dart`), `league_repository_impl.dart`, rules (`leagues`, `league_codes`), rules tests, `lib/features/leagues/**`, `leaderboard_scope_bar.dart`, leaderboard cubit scope, `watchMembersBoard`, DI, router (`/leagues`, `/leagues/:leagueId`, `/join/:code`).

- [ ] Domain tests: codes use the alphabet and are 6 long; `normalizeLeagueCode(' abc-def ')` → `ABCDEF`; invalid letters (`I`, `O`, `0`, `1`, `L`) → null; names 1–30 after trimming.
- [ ] Rules tests: get yes, list only with `array-contains` my uid; create needs owner == me, members == [me] and the code doc in the same batch; join/leave change only my uid; 31st member refused; owner can't leave; owner removes, renames, deletes (with the code doc); non-owner can't rename/remove/delete.
- [ ] Repository tests (`fake_cloud_firestore` if available): create writes both docs, join adds me, leave removes me.
- [ ] Cubit tests (`LeaguesCubit`, `JoinLeagueCubit`), members board ranking test, widget tests for the leagues screen and the join screen.
- [ ] Commit `feat(leagues): private leagues with invite codes`.

## Task 14: Hide the board while paused

**Files:** `lib/core/widgets/paused_board_cover.dart`, one line in each game screen.

- [ ] Widget test: the cover hides the child while `paused`, shows "Paused" and calls `onResume` on tap.
- [ ] Commit.

## Task 15: Account deletion

**Files:** `workers/account-deletion/src/firestore_wipe.ts` (+ tests).

- [ ] Tests: weekly entries under missing week docs are deleted; leagues I own and their code docs are deleted; I'm removed (`removeAllFromArray`) from leagues others own; writes still go in batches of 100.
- [ ] Commit.

## Task 16: Verify and review

- [ ] `flutter analyze --no-fatal-infos`, full `flutter test`, each Worker `npx tsc --noEmit -p . && npm test`, rules suite on the emulator, `dart format` on touched files only, `git checkout pubspec.lock` unless a package was added.
- [ ] Code review of `git diff feat/roadmap-batch...HEAD`, fix findings, re-run.
