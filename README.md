# Winklo

Winklo is a daily solo-puzzle app for Android, built with Flutter and Flame. Every day brings one new puzzle in each of three games — **Zip**, **Path Words** and **Sudoku** — with a live daily leaderboard, a streak per game, and progress that follows your Google account to a new phone.

- **Landing page:** <https://winklo.pages.dev> · **Privacy policy:** <https://winklo.pages.dev/privacy/> · **Delete account:** <https://winklo.pages.dev/delete-account/>
- **Play Store package:** `com.winklo.faseencm`
- **Stack:** Flutter + Flame, BLoC/Cubit, go_router · Firebase (Auth, Firestore, Analytics, Crashlytics, Remote Config, Cloud Messaging) on the free Spark plan · Cloudflare R2 (images) and Workers (avatar upload, account deletion)

## Contents

1. [What's in the app today](#whats-in-the-app-today)
2. [Project status](#project-status)
3. [Feature roadmap](#feature-roadmap)
4. [Getting started](#getting-started)
5. [Project layout](#project-layout)
6. [More docs](#more-docs)

## What's in the app today

### The three daily games

| | Zip | Path Words | Sudoku |
|---|---|---|---|
| **Goal** | Draw one path through every cell, visiting the numbers in order; walls block moves | Trace each hidden word through a sparse letter grid | Fill a 6×6 grid (2×3 boxes) with 1–6 |
| **Hints** (3 per game per day) | Reveals the next cells of the stored solution | Clears wrong strokes, otherwise reveals the next letter of a word | Explains the next logical step; never fills a cell |
| **Mistakes** | Moves that skip a cell, revisit one or cross a wall are ignored; numbers reached out of order can't win, and a tip says so | Wrong strokes stay on the board, no penalty | Free entry; a filled row, column or box that is wrong lights up |
| **Controls** | Undo, clear | Undo, reset | Notes, erase, reset |
| **First run** | Animated tutorial and rule tips | Animated tutorial and a tip | Nothing; a **?** button opens "How to play" text |
| **After clearing** | Read-only review of the path you drew (older clears show the stored solution) | Review of the found words | Review of the solved grid |

All three load the day's puzzle from Firestore (`zip_levels`, `path_words_levels`, `sudoku_levels`, doc id `daily_YYYYMMDD` for the phone's local date). The puzzles come from the separate [winklo-admin](https://github.com/MuhammedFaseenCM/winklo-admin) repo. Since 9 October a Worker cron there fills any missing day from UTC today to two days ahead: AI picks each board's size and difficulty (and writes the Path Words board), the generators build the Zip and Sudoku boards, and validators check every board. A board saved by hand in the admin CMS is locked, so the cron never overwrites it.

The clock pauses when you leave a game and the run is saved on the phone, so it survives the app being closed on the same day, and a game left open over midnight can still be finished for its own day. Players are ranked by time only.

### Around the games

- **Home:** a tile per game with "Play today's …" or "Result", the current streak, "Streak protected" while a freeze covers a missed day, and a leaderboard shortcut. Remote Config drives a soft update banner on Home and a full-screen forced update.
- **Results:** the clear time counting up, a "New personal best" badge when the time beats every earlier day, a streak badge, and a mini daily leaderboard (the top 3 plus the two players above and below you).
- **Leaderboards:** per game, daily and all-time (Remote Config `showAllTimeLeaderboard` can hide all-time), readable without signing in. Top 50 by time, updating live, with medals for the top 3. Daily rows add "Hint-free", "Flawless" (Sudoku), streak (2+ days) and "You" chips.
- **Streaks:** one per game. A single freeze covers one missed day, once.
- **Profile:** a preset or uploaded avatar, display name, sound effects toggle, privacy policy, report an issue, about (app version) and sign out.
- **Accounts and sync:** Google sign-in is required to play. Best times, clean-run flags, hint use, streaks and Zip paths sync to `users/{uid}` (today's and yesterday's results on each sync) and backfill the leaderboards. The sync isn't in a released build yet; see [Project status](#project-status).
- **Account deletion:** a web page where players sign in with Google, and the account-deletion Worker deletes their account and data straight away. In the app, Profile → Delete account signs out and opens that page in the browser.
- **Notifications:** local reminders at 08:00 ("puzzles are ready") and 20:00 ("streak at risk"), plus the FCM topics `announcements` and `app_updates`.
- **Hidden legacy games:** Word Match and Category Race are still in `lib/features/` and have routes. Nothing in the UI links to them, though a notification tap can still open them.

## Project status

As of 2026-10-10 (`8637d00`):

- **Checks:** `flutter analyze` reports only infos (no warnings or errors), and every test passes. CI (`.github/workflows/ci.yml`) runs both, plus the Workers' type checks and tests, on every push to `master` and every pull request.
- **Releases:** 1.0.0+14 has been in closed testing since 7 October. `master` adds progress sync with leaderboard backfill, the Zip path review, the redrawn icon and muted tap sounds, none of it released yet. The deployed Firestore rules already match `firestore/firestore.rules`, including the Zip `board` field, so they don't block 1.0.0+15.
- **Landed since the first roadmap:** account deletion on the web (the page on both hosts, the Worker, the rules, the privacy policy and the Data safety answers) and daily puzzle auto-generation in winklo-admin.
- **Puzzle generation is running on its fallbacks:** every generated puzzle so far says `paramsSource: local`, so the AI isn't being used, and Path Words gets the small fallback board (see [Fix first](#fix-first)). Sudoku boards come out 6×6 with 2×3 boxes, and Zip boards include a `solution`.
- **Server side:** Firebase is on the free Spark plan, so there are no Cloud Functions; server work runs in Cloudflare Workers.

## Feature roadmap

This roadmap was first written against `489ecff` (2026-10-09) and re-checked claim by claim against `8637d00` (2026-10-10). **Nothing in this section is built yet.** Each idea notes what already exists that makes it cheaper, and gives a rough size: **S** is a day or less, **M** is 2–5 days, **L** is one to two weeks or more.

How the ideas were chosen:

- They build on the three live games rather than adding new ones. A fourth game, Flow, already has its own spec.
- They favour data and code that already exist. A surprising amount is fetched, stored or written but never shown.
- They keep the landing page's promises: no ads, no clutter, and no timer you didn't ask for.

Jump to: [Fix first](#fix-first) · [Quick wins](#quick-wins-the-data-is-already-there) · [Per game](#per-game-improvements) · [Leaderboards](#leaderboards-and-competition) · [Stats](#stats-history-and-achievements) · [Habit](#habit-and-retention) · [More ways to play](#more-ways-to-play) · [Accessibility](#accessibility-and-settings) · [Platform](#platform-and-growth) · [Housekeeping](#housekeeping) · [Suggested order](#suggested-order)

### Fix first

These are bugs and mismatches found in the code. Most are small and worth landing before new features, starting with the privacy and Play policy group.

#### Privacy and Play policy

All four are done in code. Items 2–4 take effect only once deployed: `firebase deploy --only firestore:rules`, and `npm run deploy` in `workers/account-deletion`.

1. **Done: "Delete account" in the app.** Google Play requires an in-app path to account deletion. Profile → Delete account confirms, signs the app out (so this phone can't sync the account's progress back after the wipe), then opens `/delete-account/` in the browser, since Google sign-in doesn't work in the privacy WebView.
2. **Done: the deletion Worker deletes everything.** It lists the day documents with `showMissing` (the app writes `…/daily/{dayId}/entries/{uid}` and `daily_activity/{dayId}/users/{uid}` without ever creating the day documents, so a plain list found none), deletes `client_errors` too, and deletes in `batchWrite` calls of 100 to stay well inside the Workers Free plan's 50 subrequests. The Auth user goes last, only after everything else is gone, and anything short of a complete deletion is reported as an error the player can retry. The privacy policy and the deletion page now mention the `deletion_requests` record (uid, email, time, result).
3. **Done: profiles are private.** `users/{uid}`, which holds each phone's push token, is readable only by its owner or an admin. Nothing in the app reads other players' profiles; leaderboard rows carry the public name and photo.
4. **Done: leaderboard rules check identity and time.** `updatedAt`, which breaks ties, must be the write's server time or unchanged; names, photo URLs and avatar ids have length limits; and photos must come from Google or our R2 bucket, so no other server sees who opens the board. The client trims names to 40 characters and drops other photo URLs (`lib/data/leaderboard_identity.dart`), and a test pins the client, the rules and the avatar Worker's host together.

#### Gameplay and fairness

All four are done.

5. **Done: a reset keeps the clean-run flags.** Reset (Clear in Zip) still clears the board, but `usedHintsThisRun`, Sudoku's `hadMistakesThisRun`, the clock and the hints spent all carry on, so a run that used hints can't earn "Hint-free" (or "Flawless") back. The flags were already saved with the draft.
6. **Done: "New personal best" means beating earlier days.** `IsNewPersonalBest` compares the clear with the best time on every earlier daily of that game stored on the phone (`ScoreRepository.getBestDailyTimeSeconds`), so a first clear or a slower day no longer shows the badge. The Home quick win can reuse it for a lifetime best.
7. **Done: Sudoku hints point out mistakes first.** If a filled cell disagrees with the solution, the hint shades that row and says one of its digits is wrong (it costs a hint, like any other), and clears once the row is fixed. Only then does the coach teach a step.
8. **Done: a run left open over midnight finishes for its own day.** Coming back to a paused run the next day resumes it instead of discarding it, and it still posts to that day's board and streak. Only a run older than that gives way to today's puzzle. Hints are now counted per run (`HintQuotaRepository` takes the run's `playId`), so crossing midnight no longer brings three fresh hints or spends tomorrow's. A run whose app was closed overnight still starts fresh, since Home opens today's puzzle.

#### Reliability

9. **Done: the streak reminder no longer skips the day it matters.** With every game cleared, the 20:00 reminder now moves to tomorrow evening instead of being cancelled, so it still comes on a day the app isn't opened. It's a one-off: the notifications plugin fires a daily repeat at the next matching time, which would be tonight.
10. **Done: daily puzzles wait for slow connections.** All three loaders give the server 8 seconds (`dailyPuzzleServerTimeout`), then use the copy cached on the phone (`getDocPreferringServer` in `lib/core/firebase/firestore_read.dart`). They still fail when the puzzle was never cached.
11. **Done: phone photos work as avatars.** The picker scales photos to at most 512 px and re-encodes them as JPEG at quality 85, far below the 2 MiB limit, and a file that is still too large gets a clear message instead of "Could not update profile."

#### Auto-generated puzzles

12. **Fixed in winklo-admin (branch `feat/hard-daily-puzzles`, not deployed yet): daily puzzles are hard only.** Every daily puzzle is now the hardest tier ('hard', shown as Hard in the app) at the largest size the app plays: Zip 8×8, Sudoku 6×6 with 8–9 givens, and Path Words 6×6. Path Words boards are built in code: one random path through all 36 cells, cut into five or six 5–6 letter words with 3–6 blank cells scattered between them. Blanks never touch each other and every word touches at least two others, so no word stands alone; every word turns, and each can be traced only one way. The AI now only suggests unrelated, letter-sharing words (it couldn't reliably write whole boards), with a built-in list of about 300 words as the fallback. Generation takes a few milliseconds. To ship: merge to `main` (CI deploys the Worker), then delete the unlocked auto-generated docs for the coming days so the cron rebuilds them.
13. **Reject board shapes the app can't play.** The app accepts any size from Firestore. A 9×9 Sudoku renders but can never be finished (the keypad stops at 6), a 4×4 one accepts 5 and 6, and unexpected box sizes break hints. The generator could pick 9×9 about a third of the time; since item 12 it only makes 6×6 with 2×3 boxes. The app should still show a clear error for any other shape. *Where:* `SudokuPuzzle.fromJson`, the winklo-admin generator. **S**
14. **Replacing a board mid-day mixes up saved runs.** The admin lock exists so ops can swap out a bad board, but saved runs are keyed by game and day only: Zip restores the old path without re-checking it, Sudoku keeps the old digits and Path Words keeps the old found words. Save a board fingerprint with each run and drop runs that don't match. (Times from both boards still share that day's leaderboard.) *Where:* `in_progress_run_repository_impl.dart` and the restore code in the three blocs. **S–M**
15. **Path Words accepts only the stored route for each word.** A trace must match the target's `path` cell by cell, and nothing checks that a word can be traced only one way. On a generated board where a word fits two routes, a correct-looking trace is rejected. Since item 12 the generator rejects such boards; hand-made ones can still have them. *Where:* `PathWordsRules.completedTarget`, the winklo-admin validator. **S**

#### Copy and tooling

16. **Sudoku's "How to play" is out of date and easy to miss.** It still says "Wrong entries are rejected", but free entry shipped in build 13, and it only opens from the **?** button. *Where:* `AppStrings.sudokuHowToPlayBody`. **S**
17. **Done: the 08:00 reminder names all three games.** "Play Zip, Path Words and Sudoku to keep your streaks going."
18. **Done: public copy matches the app.** The landing page no longer promises Undo; the store-media brief, `pubspec.yaml`, the privacy page, `play/app_content_answers.txt` and `FIREBASE.md` describe the 6×6 Sudoku, the three games, R2 presets, resized JPEG photos, Sudoku's sign-in and the Firestore-only puzzles. Still to do by hand: the GitHub repo description ("Daily Zip path-puzzle game…") needs the repo owner (`gh repo edit MuhammedFaseenCM/winklo --description "…"` or the repo's About settings).
19. **Done: CI runs every check.** `.github/workflows/ci.yml` runs `flutter analyze --no-fatal-infos` and `flutter test`, and each Worker's type check and `npm test`, on every push to `master` and every pull request, with all actions pinned to commit SHAs (the Pages deploy too). The two stale tests are fixed, and so is a flaky one: the Path Words and Sudoku generators seeded with `Object.hash`, which Dart randomizes per run, so "the same puzzle every day" wasn't; they now use a stable FNV-1a seed (`lib/domain/stable_seed.dart`).

### Quick wins: the data is already there

1. **Show the longest streak and freezes on Home.** `HomeCubit` already loads the longest streak and whether a freeze is available, but the tiles only show the current streak and "Streak protected". The "best time" it loads is just today's time; `ScoreRepository.getBestDailyTimeSeconds` (Fix first 6) now gives a lifetime best, and `AppStrings.bestTimeLabel` is waiting for it. **S**
2. **Countdown to the next puzzle.** Show "New puzzle in 6h 12m" on cleared tiles and on Results. Home reloads when you come back to it, but not at midnight while it stays open (only the debug minute mode has a timer), so add a rollover timer. *Builds on:* `PlayPeriod`. **S**
3. **Share your result.** Add a spoiler-free share text on Results, for example `Winklo Zip · 9 Oct · ⏱ 1:12 · 🔥 5 · Hint-free`, with the landing-page link. Sharing is how daily puzzles spread, and the app has no share option anywhere. An image card or a replay of the Zip path can come later. *Builds on:* the Results data, clean-run flags and streaks. Needs `share_plus`. **S**
4. **Show your result in review mode.** Reopening a cleared game shows only the board (Sudoku adds "come back tomorrow"). Add a header such as "Cleared in 1:12 · #4 today · Hint-free" with a link to the full board. *Builds on:* the best time and flags in `ScoreRepository`, and the player's leaderboard entry. **S**
5. **"Play the next game" on Results.** Results already has a "Next puzzle" button and a `play_other` analytics value, but nothing sets `nextLevelId`, so the button never appears. Point it at the next uncleared daily instead of going back to Home. **S**
6. **Haptics.** The whole app has a single haptic tap, on Results. Add light ticks for each cell, found word and completed row, column or box, and a stronger one on a win, with a setting to turn them off. The `VIBRATE` permission is already declared. **S**
7. **Ask for a review at a good moment.** After a personal best or a 7-day streak, show Play's in-app review prompt (`in_app_review`). **S**
8. **Fill the analytics gaps.** Nothing logs sign-in, sharing, notification opens, update prompts, avatar or name changes, or freeze use, and `results_action` never fires for the three dailies. Without these events you can't measure the effect of anything else on this list. **S**

### Per-game improvements

#### Zip

- **Replay your path.** Since `489ecff` the saved path of your best-time run keeps the order you drew the cells in, so review can animate it being drawn. It would also make a good share clip. **S**
- **Feedback at each number.** Play a soft sound and haptic when the path reaches the next number. (Reject sounds for illegal moves were removed on purpose in `6d243ae`.) **S**
- **Compare with the setter's path.** Add a review toggle that overlays the stored `solution`, since many boards have more than one answer. **S**
- **Difficulty ramp.** Easier boards early in the week and harder ones at the weekend (bigger grid, fewer numbers, more walls). The auto-generator already lets AI pick each Zip board's size and difficulty, so the ramp is a rule in winklo-admin. A difficulty badge like Sudoku's needs a `difficulty` field on `ZipLevel`, which the app doesn't read today. **S–M**
- **Make sure every level has a `solution`.** Hints are disabled when it's missing. Generated boards include one, but the sample level in `FIREBASE.md` doesn't, so check any board made by hand. **S** (content check)

#### Path Words

- **Lock found words.** Undo removes the last stroke even when it was a correct word, and a test ("undo of a found word unlocks that word") locks that behaviour in. Only wrong strokes should be undoable. **S**
- **Daily theme.** Make each day's words share a theme that's revealed when you clear the puzzle ("Today: kitchen tools"). Boards are now written by AI in the winklo-admin cron, so the theme can come from the same prompt. (The `path-words-nouns` Worker only produces random nouns, and the app never calls it.) **M**
- **Word definitions.** After clearing, tap a found word to see a one-line definition, cached the same way as the noun pool. **M**
- **Bonus words.** Count real words that aren't targets as bonus finds. This needs a bigger dictionary than the bundled `en_words.txt` (2,482 words, which no code reads today). **M**

#### Sudoku

- **Undo.** The landing page promises it, and the other two games have it. **S–M**
- **Highlight related cells.** Shade the selected cell's row, column and box, and every cell with the same digit, as most Sudoku apps do. **S**
- **Tidy notes automatically.** Placing a digit should remove it from the notes in the same row, column and box (as an option). **S**
- **Digit counter.** Show how many of each digit are left on the keypad, and dim the ones that are finished. **S**
- **First-run help.** Zip and Path Words open an animated tutorial on first run; Sudoku shows nothing until you find the **?** button. **S–M**
- **Weekend 9×9.** Offer a bigger board on Saturdays and Sundays (deferred in the 6×6 spec). Beyond the layout, 6 is hard-coded in the rules (`digitMax`), the keypad, the notes grid and the hint coach. **L**

### Leaderboards and competition

- **Your rank beyond the top 50.** The board loads only the top 50, and your own row is pinned only when it's among them. A Firestore `count()` of faster times gives "You're #132 of 1,204". The app gives tied times the same rank with no gap (1, 2, 2, 3), while counting gives 1, 2, 2, 4, so pick one. **S–M**
- **Percentile on Results.** "Faster than 78% of today's players", from the same counts. Two post-game specs deferred a "you'd be #N" teaser for guests. **S**
- **Past days' boards.** The repository and use case already take a `dayId`; the cubit never passes one. Add a date picker to the daily board. **S–M**
- **Hint-free filter.** Entries already store `usedHints` (for the best-time run), so a toggle can rank only clean runs. It needs a composite index; since Fix first 5 the flag can be trusted. **S–M**
- **Weekly board.** Rank by total or average time across the week's clears, with a Worker cron adding up the daily boards (Spark has no Cloud Functions). **M–L**
- **Tap a player.** Open a small card with their avatar, name and streak, all of which are already on the entry. The rules now limit names and photos (Fix first 4), but the streak on an entry still can't be checked. **S**
- **Report a player.** Names and uploaded photos are shown to every player, with no way to report or hide one, and the avatar Worker checks only the declared type and the size. Google Play's user-generated content policy expects in-app reporting and blocking. Add "Report" to leaderboard rows, check the JPEG bytes in the Worker, and keep a way to reset a name or photo. **S–M**
- **Friends and private leagues.** Use invite codes to make a filtered board for friends, family or a team. This needs a small social graph and new rules. **L**
- **Fair play.** The board is easy to game today. The rules accept any whole number of seconds, anyone can read a puzzle and its solution up to two days early, the leaderboard day isn't checked, and the clock stops while the app is in the background. Hide the board while paused, add a minimum time per game and block reads of future dailies in the rules, and send submissions through a Worker that checks the board. **M**

### Stats, history and achievements

- **Stats screen.** Per game: clears, current and longest streak, best and average time, how often you clear without hints, a time histogram and a calendar of cleared days. Synced history lives in `users/{uid}/game_days` (time, points, hints, mistakes) and owners can read it, but only from 1.0.0+15 on, and each sync covers only today and yesterday. Older days exist only on each phone, so the stats screen needs a one-time upload of the local history first. **M**
- **Achievements.** First clear, 7/30/100-day streaks, a Zip under a minute, a week without hints, ten flawless Sudokus, a perfect day with all three cleared. Compute them from the same day records and show them on Profile. **M**
- **Personal-best trend.** A small chart of clear times over the last 30 days. **S** once the stats screen exists.
- **Today's summary on Home.** "2 of 3 cleared · 3:41 total", with a "Perfect day" badge when all three are done. **S**

### Habit and retention

- **Earn freezes back.** Today each game gets one freeze for good: `GameStreak.freezeAvailable` is only ever set to false. Earn one for each 7-day streak (up to two, say), show the count on Home, and tell players when a freeze saved their streak. Add a new count field rather than retyping the bool: older builds keep writing it, and the rules only accept listed fields. **M**
- **Smarter reminders.** The 20:00 reminder is scheduled whenever any game is uncleared, even when no streak is at stake, and its text is generic. Name the streak at risk ("Your 12-day Zip streak ends at midnight"), skip the reminder when there is nothing to lose, and let players choose the time and which reminders they get (per-type toggles were deferred in the notifications spec). Give reminders and announcements separate Android channels; one channel carries both today. **M**
- **Home-screen widget.** Show today's status for each game, the streak and the countdown, and open straight into a game. **M–L**
- **Weekly recap.** A Sunday notification or Home card: "This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak". **M**
- **Snooze the update banner.** The soft update banner can't be dismissed; let players hide it for a day (deferred in the force-update spec). **S**

### More ways to play

- **Archive.** Let players play any past day's puzzle. Past dailies stay in Firestore under their `daily_YYYYMMDD` ids as long as winklo-admin keeps them. The game screens take a `date`, but the routes never pass one, and the games aren't ready for it: Zip's clock stays at 0 when given a date, Path Words and Sudoku jump to today's puzzle on resume, and a past clear would post to that day's board, reset the streak and spend today's hints. Archive runs need their own mode that skips streaks and boards (and can keep its own best time). **M–L**
- **Practice mode.** Offer endless offline puzzles from the generators already in the repo (`DailyPuzzleGenerator`, `PathWordsGenerator`, `SudokuGenerator`), whose generation code only tests use today. No leaderboard or streak. **M**
- **Weekend specials.** A bigger or themed board on Saturday and Sunday for each game (see the Zip difficulty ramp and the Sudoku 9×9 idea). **M–L**
- **Offline safety net.** If Firestore can't be reached and today's puzzle isn't cached, the game shows an error with Retry. The auto-generator keeps UTC today + 2 days published, so the app can prefetch tomorrow's puzzle while online (Home only warms today's Zip). Since Fix first 10, a slow connection falls back to that cached copy. **S–M**
- **Word Match and Category Race.** Both still work and are routed, but the Flow spec lists reviving them as dailies as a non-goal. Only bring them back as bonus games, with the same polish as the dailies. **L**

### Accessibility and settings

- **A settings screen.** Today only sound has a toggle. Put sound, haptics, reminders, an optional on-screen timer and reduced motion in one place. **M**
- **Optional visible timer.** A running clock exists but only shows in debug builds (`DevRunTimerLabel`). Offer it as an opt-in setting, in keeping with "no timer you didn't ask for". **S**
- **Respect the system font size.** `AppTextScale` turns off OS text scaling for the whole app so layouts stay fixed. Allow scaling up to about 1.3× outside the boards, which means replacing that app-wide wrapper. **S–M**
- **Reduced motion.** Respect the system "remove animations" setting for the ember burst, sparks and shimmer. **S**
- **Screen readers.** The Flame boards expose nothing to TalkBack. Add a semantics layer that describes the cells, starting with Sudoku, where it's easiest. **M–L**
- **Colour-blind-friendly palette.** Path Words and Sudoku rely on colour: strokes differ only by hue (and wrong strokes look like found words), and Sudoku marks errors with a rose tint next to teal hint shading. Add patterns or outlines, or a high-contrast palette. **M**

### Platform and growth

- **Links that open the game.** Add App Links for `winklo.pages.dev/zip` and similar (with `assetlinks.json` on Pages), so shared results and announcements open the right screen. The app only declares a launcher intent filter today. **M**
- **Play in-app updates.** Use Play's in-app update API instead of sending players to the store page (deferred in the force-update spec). **S–M**
- **iOS.** There's no `ios/` folder yet, and `firebase_options.dart` throws on iOS. It needs a Firebase iOS app, APNs for push and the Google Sign-In URL scheme. App Store rules will likely require Sign in with Apple, and they require account deletion inside the app (guideline 5.1.1(v)); the deletion Worker already accepts any Firebase sign-in. **L**
- **Other languages.** Nearly all UI text is in `AppStrings`; a few inline strings (such as "Your Rank", "Next puzzle" and the "Player" fallback name) and raw error messages need moving first. After that, a move to ARB files is straightforward. Path Words would also need word content in each language. **L**
- **Revenue without ads (optional).** If it's ever needed, keep the no-ads promise, for example with a one-time supporter pack that unlocks the archive and extra avatars. **M**

### Housekeeping

These aren't features, but they affect how cheap the ideas above are:

- The generation code in `DailyPuzzleGenerator`, `PathWordsGenerator` and `SudokuGenerator` runs only in tests (`DailyPuzzleGenerator.dateId` is production code, and `SudokuGenerator` is an unused default in `SudokuBloc`). winklo-admin now has TypeScript ports of the Zip and Sudoku generators, so there are two copies to keep in step. Reuse the Dart ones for practice mode, or move `dateId` out and delete them.
- `generate_daily_path_words.dart` and `generate_daily_sudoku.dart` sit in `lib/domain/usecases/` but import `cloud_firestore`, and they fetch rather than generate. Move them behind repositories, as Zip already is, to keep `domain/` pure Dart as CLAUDE.md asks.
- `FetchZipLevels`, the bundled `assets/zip/levels/*` and `en_words.txt` are unreachable. `WordListRepository` and the `path-words-nouns` client are registered but never read, so that Worker is never called.
- Path Words' `hintFlashCell` and Sudoku's `hintFlashIndex` (with its drawing code) are left over from older hints; today's hints are drawn another way.
- The replay fields in `ResultsArgs` are ignored for the dailies, and guest-play code (for example `results_board_tease.dart`) remains from before sign-in became compulsory.
- `SfxService.tapSoundEnabled` is still `false` ("muted for now").

### Already designed elsewhere

- **Flow**, a fourth daily game (draw non-crossing paths between matching pairs), has an approved spec and plan in `docs/superpowers/` but no code. It's out of scope here because it's a new game.
- **Account deletion** (spec and plan dated 2026-10-09) is built and live: the page, the Worker, the rules and the policy updates. Its spec left the in-app button out of v1; it was added afterwards (Fix first 1), along with the Worker fixes in Fix first 2.
- **Daily puzzle auto-generation** (spec and plan dated 2026-10-09) is built in winklo-admin and needed no app changes. It changes some of the ideas above: the Zip difficulty ramp becomes a generator rule, and the generators now exist twice (see [Housekeeping](#housekeeping)).
- Ideas the specs deferred are folded into the sections above: profile stats, "you'd be #N", per-type notification toggles, in-app updates and the banner snooze, 9×9 and practice Sudoku, anti-cheat, iOS and localization.

### Suggested order

| Phase | Ideas | Why |
|---|---|---|
| **Now** (one to two weeks, mostly S) | Everything in [Fix first](#fix-first), privacy and Play policy first; the longest streak and countdown on Home; sharing; the review header; "play the next game"; haptics; the analytics gaps | Closes the Play-policy and privacy gaps, makes the chips and personal bests honest, and makes later changes measurable |
| **Next** (2–4 weeks, mostly M) | Fair play and reporting players; Sudoku undo and highlighting; earning freezes back; smarter reminders and a settings screen; rank beyond the top 50 and percentile; past days' boards; the stats screen | Protects the leaderboard, strengthens the daily habit and gives players more reasons to come back |
| **Later** (mostly L) | Archive; practice mode; achievements; weekend specials; home-screen widget; App Links; friends leagues; screen-reader support for the boards; iOS; other languages | Bigger bets, once the core loop can be measured |

## Getting started

**Requirements:** Flutter with Dart `^3.12.1`, the Android SDK, and access to the Firebase project `brain-zip-app`. `android/app/google-services.json` and `lib/firebase_options.dart` are committed.

```bash
flutter pub get
flutter run --dart-define=DAILY_PLAY_PERIOD=true
```

- **`DAILY_PLAY_PERIOD=true`** makes a debug build use calendar days, like release. Without it, a debug build looks for a new puzzle every minute; those docs usually don't exist, so you get "Could not load today's puzzle". In VS Code, use the "winklo (daily play period)" launch config; the default "winklo" config doesn't pass the flag.
- **Sign-in:** playing needs Google sign-in, so your debug key's SHA-1 must be registered on the Firebase Android app.
- **Debug data is only partly separate:** debug builds keep progress and leaderboards apart (`leaderboards_debug`, `users/{uid}/game_days_debug`, `game_streaks_debug`) but share everything else with production, including the puzzles, `users/{uid}` itself, `daily_activity`, `issue_reports` and `client_errors`.
- **Other build flags** have production defaults: `STATIC_ASSETS_BASE_URL` (R2 images), `AVATAR_UPLOAD_BASE_URL` (the photo upload Worker; if it's empty, the picker still shows but uploads fail) and `PATH_WORDS_NOUNS_BASE_URL` (unused).

**Checks**

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # after changing freezed classes; generated files are committed
```

**Firebase rules:** `firebase deploy --only firestore:rules`. Deploy the rules **before** shipping a build that writes a new Firestore key; see [FIREBASE.md](FIREBASE.md).

**Release:** signing reads `android/key.properties`, which isn't committed; without it, release builds quietly fall back to the debug key, which Play rejects. fastlane and the `play/*.py` scripts also need `play/play-service-account.json` (not committed). Build with `flutter build appbundle`, then upload with fastlane: `fastlane internal`, `fastlane closed` (the alpha track) or `fastlane testing` (both). `fastlane listing` and `play/upload_listing.py` update the store listing, and `play/upload_data_safety.py` updates the Data safety form.

**Workers:** in `workers/avatar-upload`, `workers/account-deletion` or `workers/path-words-nouns`, run `npm test`, `npm run dev` or `npm run deploy`. The account-deletion Worker also needs the `FIREBASE_SERVICE_ACCOUNT_JSON` secret (`npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON`) and shares the `winklo-avatars` R2 bucket with avatar-upload.

## Project layout

```
lib/
  core/            shared code: router, DI, theme, strings, sound, lifecycle, widgets
  domain/          pure Dart: entities, repository interfaces, use cases, game rules
  data/            Firebase, R2 and SharedPreferences implementations of the repositories
  features/        one folder per screen or game: zip, path_words, sudoku, home, results,
                   leaderboard, profile, auth, dashboard, app_update
                   (plus the hidden word_match and category_race)
test/              mirrors lib/, plus a Firestore rules whitelist test
firestore/         security rules and indexes
workers/           Cloudflare Workers: avatar-upload and account-deletion (used),
                   path-words-nouns (unused)
tool/, tools/      icon and avatar generators, demo leaderboard seeding, R2 source art
play/, fastlane/   Play listing, Data safety and release lanes
docs/              landing page, privacy policy and account-deletion page (deployed to
                   Cloudflare Pages, mirrored on GitHub Pages);
                   docs/superpowers/ holds design specs and plans
```

The architecture rules (feature-first folders, the domain/data split, Cubit or Bloc, DI) are in [CLAUDE.md](CLAUDE.md).

## More docs

- [FIREBASE.md](FIREBASE.md): Firebase setup, collections, security rules, Remote Config and notifications
- [CLAUDE.md](CLAUDE.md): architecture and conventions
- [docs/superpowers/specs/](docs/superpowers/specs/): design specs, with matching plans in `docs/superpowers/plans/`
