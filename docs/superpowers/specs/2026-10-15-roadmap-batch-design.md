# Roadmap batch: 33 ideas from the README

Date: 2026-10-15. Base: `feat/home-review-haptics` at `8b3daff` (it contains `feat/quick-wins`; neither is merged into `master`, which is at 1.0.0+16).

This spec covers the roadmap ideas chosen on 2026-10-15. It fixes the contracts that more than one area depends on (data shapes, rules, the Worker API, file ownership), so the areas can be built in parallel. Decisions taken with the user:

- **Fair play** is staged: the new build submits through a Worker, the rules keep accepting direct writes (with a minimum time and a valid day) until the minimum build is raised, then one flag in the rules turns direct writes off.
- **Themes and definitions** come with the puzzle: the winklo-admin cron asks for themed words and a one-line definition of each.
- **Languages:** Malayalam (plus English). Path Words boards stay English.
- **Weekend specials** are harder boards at the same size, with a badge. Older builds can play them.

Nothing is deployed by this work. Deploy steps are listed at the end and go into the README.

## Delivery

| Branch | Repo | Area | Wave |
|---|---|---|---|
| `feat/roadmap-batch` | winklo | integration branch; every area merges here, and this is what's pushed | — |
| `feat/rb-polish` | winklo | A. Polish and platform | 1 |
| `feat/rb-path-words` | winklo | B. Path Words content + weekend badge (app side) | 1 |
| `feat/themes-definitions-weekends` | winklo-admin | B. Themes, definitions, weekend params (from `main`, never merged to `main` by us: `main` deploys) | 1 |
| `feat/rb-leaderboards` | winklo | C. Leaderboards, leagues, fair play, new Worker | 1 |
| `feat/rb-stats` | winklo | D. Stats and achievements | 1 |
| `feat/rb-habit` | winklo | E. Habit, reminders, widget, settings screen | 1 |
| `feat/rb-more-play` | winklo | F. Archive, practice, bonus games | 2 (after wave 1 merges; it touches every game bloc) |
| `feat/rb-malayalam` | winklo | G. Localization | 3 (last; it touches every string) |

Version: **1.1.0+19** with `changelogs/19.txt`, set once at the end on the integration branch.

Shared rules for every area:

- Follow CLAUDE.md: feature-first, pure-Dart `domain/`, repositories behind interfaces registered in `core/di/`, Cubit by default, `bloc_test` + `mocktail`, all copy in `AppStrings`.
- Tests first for logic (TDD). Every area ends with `flutter analyze --no-fatal-infos` clean and the full `flutter test` passing (baseline: 939 tests pass).
- `dart format` only the files you touched. `pubspec.lock` changes only for packages you add.
- Hotspot files (`home_screen.dart`, `app_router.dart`, `app_strings.dart`, `core/di/*`, `firestore.rules`, game blocs): keep edits small and additive. Put new UI in new widget files and add one line to the hotspot.
- No debug builds on the adb phone (it runs the Play build). Screenshot tests at 360×640 for new screens.

## A. Polish and platform (`feat/rb-polish`)

1. **Zip: replay your best path.** In review mode (a reopened clear), a **Replay** button under the board animates the saved path being drawn in order (`clear_board_zip_daily_*`, "r,c;r,c"), about 12 cells a second, then rests on the full path. `ZipGame` gets a one-shot `replay(List<Cell>)` with an `onReplayFinished` callback; the state of whether it's playing stays in the bloc or cubit. Hidden when there's no saved path (falls back to the solution today, which isn't the player's path).
2. **Today's summary on Home.** Above the tiles: "2 of 3 cleared · 3:41 total" (the sum of today's clear times), and a "Perfect day" badge when all three are done. Hidden when none are cleared. Built from `HomeCubit` state, which already has today's clears.
3. **Snooze the update banner.** A close button on the soft banner hides it for 24 hours (`update_banner_snoozed_until` in shared_preferences). The forced screen can't be snoozed.
4. **Play in-app updates.** `in_app_update`: the soft banner's Update button starts a flexible update and shows "Restart to update" when it's downloaded. The forced screen starts an immediate update. Both fall back to the store URL when the API isn't available (sideloaded or debug builds). Behind an `InAppUpdateRepository`.
5. **Prefetch tomorrow's puzzle.** After Home loads, and once tomorrow's local day is live (10:00 UTC on the day before, the same rule as `daily_live.ts`), read tomorrow's three puzzle docs once so Firestore caches them. Ignore every error (permission-denied included). At most once per app session per day.
6. **App Links.** Verified `https` links on `winklo.pages.dev`:
   - Paths: `/zip`, `/path-words`, `/sudoku`, `/leaderboard`, `/join/{code}` (`/join` belongs to area C; this area routes it to a placeholder until C lands).
   - Android intent filter with `autoVerify`, and `docs/.well-known/assetlinks.json`. The SHA-256 fingerprint comes from the Play-signed APK on the adb phone (`adb shell pm path com.winklo.faseencm`, pull it, `keytool -printcert -jarfile`). This only reads; nothing is installed. If the phone isn't connected, list it as a manual step rather than shipping a placeholder.
   - Each path gets a small static page in `docs/` that sends people without the app to the landing page.
   - `go_router` handles the paths. Signed-out users still get `playAuthRedirect`.
   - The share text uses the game's link (`https://winklo.pages.dev/zip`).

## B. Path Words content and weekends (`feat/rb-path-words` + winklo-admin `feat/themes-definitions-weekends`)

**winklo-admin:**

- The AI prompt (`path_words_ai_generate.ts`) asks for a short theme ("Kitchen tools", 2–24 characters) and words on that theme, each with a definition (8–90 characters, plain, not containing the word). The old "no theme" rule goes.
- The board builder records which words it used. Fields added to the `path_words_levels` doc:
  - `theme: string | null`
  - `definitions: { [WORD]: string }`, for the target words only.
- When the AI fails and the local pool is used, `theme` is null. Give `path_words_word_pool.ts` a definition for each fallback word, so definitions are always there.
- `validateCmsDocument` accepts both fields, and the CMS Path Words editor can edit the theme and each definition.
- **Weekend specials:** `dailyPuzzleParams` takes the date. On a Saturday or Sunday (by the dateId's calendar date) it returns weekend params and the doc gets `special: 'weekend'`.
  - Zip: 8×8, fewer numbers and more walls than the weekday hard tier.
  - Sudoku: 6×6 with exactly 8 givens (the minimum for one answer) and the generator's hardest rating.
  - Path Words: 6×6, five 6-letter words and 6 blanks.
  - The generators' existing guarantees still hold: one solution, one route per word, words touch.
- Tests in both the SPA and the Worker. Run `npm run typecheck`, lint and tests. Push the branch; don't merge it to `main`.

**App:**

- `PathWordsPuzzle` gets `theme` (nullable) and `definitions` (`Map<String, String>`, empty when missing). `SudokuPuzzle`, `ZipLevel` and `PathWordsPuzzle` all get `special` (nullable string). Unknown fields are ignored. The fingerprints don't include these, so changing a theme doesn't drop a saved run.
- **Theme reveal:** after a clear, Results and the review card show "Today: Kitchen tools". It's never shown before the clear.
- **Definitions:** after a clear (Results' word list and review mode), tapping a found word opens a sheet with the word and its definition. Words without a definition aren't tappable.
- **Lock found words:** Undo removes the active stroke, or the last wrong stroke. It never removes a found word. Replace the test "undo of a found word unlocks that word" with the opposite. Reset still clears everything.
- **Bonus words:**
  - Bundle a public-domain list (ENABLE, `enable1.txt`), filtered to 4–8 letters, lowercase, as `assets/words/en_bonus_words.txt`. It replaces the unused `en_words.txt`.
  - Load it lazily into a `Set` behind `WordListRepository`.
  - A finished stroke that isn't a target but spells a word in the list (and isn't already a bonus) counts as a bonus word: a light haptic, a "Bonus word: STARE" toast, and the stroke clears without counting as a wrong stroke.
  - Bonus words are saved with the run's draft and clear meta, and Results shows "3 bonus words". They don't affect the time, the leaderboard or the clean-run flags.
- **Weekend badge:** when `special == 'weekend'`, the Home tile and the game header show "Weekend special".

## C. Leaderboards, leagues and fair play (`feat/rb-leaderboards`)

**Past days' boards.** `LeaderboardCubit` takes a `dayId`. The daily tab gets a strip of the last 14 days (Today, Yesterday, then dates). Past days are read-only snapshots, using the same `watchBoard(dayId:)`.

**Tap a player.** Tapping a row opens a sheet with the avatar, name, time, clean-run chips and streak, all from the entry.

**Weekly board.**

- A new period, `weekly`, shown as a "This week" tab.
- Path: `leaderboards/{gameId}/weekly/{weekId}/entries/{uid}`. `weekId` is the ISO week of the local dayId, `yyyy-Www`.
- Fields: `displayName, photoUrl, avatarId, days: {dayId: seconds}, daysCleared: int, totalSeconds: int, updatedAt`.
- Rank: `daysCleared` descending, then `totalSeconds` ascending, then `updatedAt` ascending. Add the composite index to `firestore.indexes.json`.
- Only the Worker writes weekly entries. Each accepted submission upserts that day's best time and recomputes the totals. No cron is needed.
- A row reads "5 days · 6:12".
- Release root only (`leaderboards`). The debug root shows the tab empty, with a note.

**Friends and private leagues.**

- `leagues/{leagueId}`: `{name (1–30 chars), ownerUid, code, memberUids (1–30 uids), createdAt}`.
- `league_codes/{CODE}`: `{leagueId}`. The code is 6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`.
- Create a league (the creator is its first member), share the invite (`https://winklo.pages.dev/join/CODE`), join with a code, leave. The owner can remove members, rename the league or delete it.
- The leaderboard screen gets a scope picker: Everyone, then each of my leagues.
- A league's board fetches the members' entries with `whereIn` on the document id (30 at most) and sorts them on the phone with the same rank rules. That works for daily, weekly and past days.
- Rules:
  - A signed-in user can `get` a league or a code doc, but not list them.
  - Members can list with `array-contains` their uid.
  - Create: `ownerUid == auth.uid` and `memberUids == [auth.uid]`. The code doc is created in the same batch.
  - Join or leave: the only change is adding or removing your own uid, and members stay at 30 or fewer.
  - The owner can remove others, rename, or delete the league and its code doc.
- `workers/account-deletion` also removes the user from leagues, deletes the leagues they own (and their codes), and deletes their weekly entries.

**Fair play.**

- **New Worker `workers/leaderboard`** (`winklo-leaderboard`), at `https://winklo-leaderboard.winklo.workers.dev` (a `String.fromEnvironment` config, like the avatar Worker). It reuses `firebase_auth.ts` and `google_auth.ts` from `account-deletion`.
- **Endpoint:** `POST /v1/submit` with `Authorization: Bearer <Firebase ID token>`. The body:
  `{gameId, dayId: 'yyyy-MM-dd', timeSeconds, usedHints, hadMistakes, currentStreak, displayName, photoUrl, avatarId, proof}`.
  The proof depends on the game:
  - Zip: `path` (a list of `[r,c]` in the order drawn).
  - Sudoku: `grid` (36 ints).
  - Path Words: `strokes` (`[{targetId, cells:[[r,c],…]}]`).
- **Checks:**
  - A valid ID token.
  - `gameId` is one of the three games.
  - `dayId` is live: from 10:00 UTC on the day before to 12:00 UTC on the day after.
  - `timeSeconds` is a whole number from the game's minimum up to 86 400. The minimums are Zip 10 s, Path Words 15 s, Sudoku 15 s, defined in one place and also used by the rules.
  - The puzzle is read from `{collection}/daily_{YYYYMMDD}` of that date, and the proof must solve it:
    - Zip visits every cell exactly once, in orthogonal steps, never through a wall, and reaches the numbers in order.
    - Sudoku's grid equals the solution.
    - Path Words: each target is traced exactly once along adjacent cells and spells its word.
  - Identity fields are cleaned with the same limits as the rules: names trimmed to 40 characters, photos only from Google or our R2 host.
  - `currentStreak` is capped at the synced `users/{uid}/game_streaks/{gameId}.current + 1`.
- **Writes,** in one `:commit` with an `updateTime` precondition, retried once on contention:
  - the daily entry and the all-time entry, each written only if the time improves (the streak and identity are always refreshed);
  - the weekly entry.
- **Responses:** `200 {accepted, improved, rank: null}`. `400` or `422` with `{error: code}`, with codes `bad_request, not_live, too_fast, bad_proof, unknown_puzzle`. `401` for a bad token.
- **App side:**
  - `LeaderboardRepositoryImpl.submitBestTime` posts to the Worker (a new `LeaderboardSubmitClient` in `data/clients`).
  - On a network error or a 5xx, it falls back to the direct Firestore write as today, so the staged rollout never loses a time. A 4xx is final and is logged to Crashlytics as a non-fatal.
  - Debug builds (the `leaderboards_debug` root) keep writing directly.
  - Each game bloc passes the proof into `SubmitLeaderboardTime`.
- **Hide the board while paused:** the three game screens cover the board while the run is paused or the app is in the background.
- **Rules, phase 1 (ships with this release):**
  - Daily leaderboard creates and updates need `timeSeconds >= minSeconds(game)`, a `dayId` that matches `^\d{4}-\d{2}-\d{2}$`, and that day is live at `request.time`.
  - The three puzzle collections refuse reads of a `daily_YYYYMMDD` doc before it goes live (admins can read it at any time). Other ids are unchanged.
  - Weekly entries: public read, no client writes.
  - Leagues as above.
  - A single function, `directLeaderboardWritesAllowed()`, returns `true`.
- **Phase 2 (manual, after `minBuildNumber` reaches 19):** change that function to `false` and deploy the rules. The README says when and how.
- **Tests:** the Worker's tests cover every check and proof. `test/firestore` pins the minimum times and the field lists across the app, the rules and the Worker.

## D. Stats and achievements (`feat/rb-stats`)

- **One-time history upload.**
  - On a signed-in sync, if `history_uploaded_{uid}` isn't set, the app reads every local clear (`best_time_*`, `clear_meta_*` and `clear_board_*` for the three games' daily mode keys) and writes the missing ones as `users/{uid}/game_days/{gameId}_{playId}` docs, in batches of 400.
  - It then sets the flag.
  - Writes that the rules reject (they don't regress) are skipped.
  - Check the rules allow old `playId`s, and widen them only if needed.
- **Stats screen,** at `/profile/stats` and reached from Profile. It has a tab per game:
  - clears; current and longest streak; best and average time; the share of hint-free clears;
  - a histogram of clear times (5 buckets);
  - a calendar of cleared days, month by month;
  - a personal-best trend: a line of the last 30 days' clear times, with the running best.
  - The data is the merge of `game_days` from Firestore and the local history.
  - Charts are `CustomPainter`s, so there's no new chart package.
  - Each chart has an empty state.
- **Achievements.** These are computed from the same day records and streaks, as pure functions in `domain/achievements/`:
  - first clear (per game);
  - 7, 30 and 100-day streaks (per game);
  - a Zip under a minute;
  - a week without hints: 7 days in a row of hint-free clears in one game;
  - ten flawless Sudokus;
  - a perfect day: all three cleared on the same day.
  - They appear as a badge grid on Profile, locked ones dimmed with their condition.
  - Newly unlocked ones (compared with a stored set) show a banner on Results once.

## E. Habit, reminders, widget and settings (`feat/rb-habit`)

- **Earn freezes back.**
  - `GameStreak` gets `freezeCount` (int, 0–2).
  - A clear that brings the current streak to a multiple of 7 earns one, up to 2.
  - A 2-day gap spends one.
  - `freezeAvailable` is still written, as `freezeCount > 0`, for older builds. When `freezeCount` is missing, it's read from `freezeAvailable` (1 or 0).
  - The rules accept `freezeCount` (an int from 0 to 2) in `validGameStreak`.
  - Home shows the count (a snowflake ×2).
  - When a freeze saves a streak, Home shows "Your freeze saved your 12-day Zip streak" once.
- **Smarter reminders.**
  - The 20:00 reminder names the longest streak at risk: "Your 12-day Zip streak ends at midnight". With several at risk, it adds "and 2 more".
  - It isn't scheduled when no uncleared game has a current streak of at least 1.
  - In Settings, players choose the daily-ready time (default 08:00) and the streak reminder time (default 20:00).
  - Each type can be turned on or off: daily ready, streak at risk, weekly recap, and announcements (which subscribes to and unsubscribes from the FCM topic).
  - There are two Android channels: `winklo_reminders` (reminders and the recap) and `winklo_announcements` (FCM announcements and app updates).
  - The manifest's default FCM channel becomes `winklo_announcements`. Create both channels at start-up, and keep the old one so already-scheduled notifications still show.
- **Weekly recap.**
  - A Sunday notification, at the streak-reminder time minus one hour: "This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak".
  - It's computed from the local history and rescheduled on each app open and each clear.
  - A Home card on Sunday and Monday shows the same week. It can be dismissed until next week.
- **Home-screen widget (Android).**
  - Uses `home_widget`, with a Kotlin `AppWidgetProvider` and a RemoteViews layout.
  - It shows the three games, each with ✓ or 🔥N, and "New puzzle at midnight".
  - It's updated on app open, on each clear and on midnight rollover, and `updatePeriodMillis` is 30 minutes.
  - Tapping a game opens it through the home_widget launch URI (`winkloapp://play/zip`), which the router maps.
  - It uses the app's colours, light and dark.
- **Settings screen,** at `/profile/settings` and reached from Profile. It has three sections:
  - Sound and vibration (moved from Profile, both signed-in and signed-out).
  - Reminders: the toggles and times above.
  - Language: a row for area G to fill in, hidden until G lands.
  - Settings live behind a `SettingsRepository`, reusing the existing sfx and haptics repositories.

## F. More ways to play (`feat/rb-more-play`, wave 2)

- **Play modes.** A `PlayMode` (`daily | archive | practice`) is passed with the route (`/zip?mode=archive&day=2026-10-09`, `/zip?mode=practice`).
  - Only `daily` touches streaks, leaderboards, `daily_activity`, the daily best time, hint quotas per day, the reminder and the widget.
  - Archive and practice runs use their own mode keys (`zip_archive_{playId}`, `zip_practice`) for drafts and best times.
  - Fix the known date issues: Zip's clock stays at 0 when given a date, and Path Words and Sudoku jump to today on resume.
- **Archive.**
  - Home has an "Archive" entry. It opens a month calendar from the first hard daily (11 October 2026) to yesterday, for one game at a time.
  - Each day shows ✓ when it's cleared, in the daily or in the archive.
  - Picking a day plays it in archive mode with 3 hints per run.
  - Results for an archive run show the time, "Archive · 9 Oct" and the archive best. There's no board, no streak and no share of a rank.
  - The puzzles are read like the dailies, and past days are always live.
- **Practice mode.**
  - Home has a "Practice" entry that offers endless offline boards from the Dart generators (`DailyPuzzleGenerator`, `PathWordsGenerator`, `SudokuGenerator`), each with a random seed.
  - A "New board" button. No leaderboard, streak or hint limit.
  - Path Words practice draws words from the bundled lists.
  - This settles the housekeeping note about the unused generators.
- **Bonus games.**
  - A "Bonus games" section under the dailies on Home: Word Match and Category Race.
  - Bring them up to the dailies' polish: How to play on the first run, the haptics and sfx services, the shared Results layout (time and a local best, with no leaderboard or streak), the app theme, and no leftover debug UI.
  - Their content still comes from the CMS decks.

## G. Malayalam (`feat/rb-malayalam`, wave 3)

- Add `flutter_localizations` and gen-l10n, with `lib/l10n/app_en.arb` and `app_ml.arb`.
- `AppStrings` stays the API, so non-UI code (notifications, share text) still works. Its members become getters backed by the current `AppLocalizations`. That instance is set when the locale changes (`lookupAppLocalizations`). Remove the `const` uses this breaks.
- Move the inline strings the README lists ("Your Rank", "Next puzzle", the "Player" fallback) and the raw error messages into it.
- Every string from waves 1 and 2 gets translated.
- The Malayalam text is natural and short, with game names kept in English. Note in the README that it needs a native speaker's review.
- Fonts: add Noto Sans Malayalam through google_fonts as a `fontFamilyFallback`.
- The Settings Language row offers System, English and മലയാളം, stored in shared_preferences.
- Screenshot tests of Home, a game, Results, Settings and Stats in Malayalam at 360×640, with no overflow.
- Dates and numbers are formatted by locale (`intl`).

## Deploy steps (README)

1. Firestore rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes`. This is phase 1 and is safe for older builds.
2. Leaderboard Worker:
   - `cd workers/leaderboard && npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON && npm run deploy`.
   - Then account-deletion: `npm run deploy`.
3. winklo-admin: merge `feat/themes-definitions-weekends` into `main`, which deploys the SPA and the Worker. Check the next Path Words day has a `theme` and `definitions`, and that a Saturday has `special: 'weekend'`.
4. Pages: the `docs/` deploy publishes `assetlinks.json` and the link pages.
5. Release 1.1.0+19.
6. Once most players are on +19: set `minBuildNumber` to 19, then do fair-play phase 2 in the rules.
