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

This describes the code in this repo. The released build doesn't have all of it yet; see [Project status](#project-status).

### The three daily games

| | Zip | Path Words | Sudoku |
|---|---|---|---|
| **Goal** | Draw one path through every cell, visiting the numbers in order; walls block moves | Trace each hidden word through a sparse letter grid | Fill a 6×6 grid (2×3 boxes) with 1–6 |
| **Hints** (no limit; each adds time to the run: +10s, then +20s, up to +60s a hint) | Reveals the next cells of the stored solution | Clears wrong strokes, otherwise reveals the next letter of a word | Explains the next logical step; never fills a cell |
| **Mistakes** | Moves that skip a cell, revisit one or cross a wall are ignored; numbers reached out of order can't win, and a tip says so | Wrong strokes stay on the board, no penalty | Free entry; a filled row, column or box that is wrong lights up |
| **Controls** | Undo, clear | Undo, reset | Notes, erase, reset |
| **First run** | Animated tutorial and rule tips | Animated tutorial and a tip | "How to play" opens once, with the clock paused; the **?** button opens it again |
| **After clearing** | Read-only review of the path you drew (older clears show the stored solution) | Review of the found words | Review of the solved grid |

All three load the day's puzzle from Firestore (`zip_levels`, `path_words_levels`, `sudoku_levels`, doc id `daily_YYYYMMDD` for the phone's local date). The puzzles come from the separate [winklo-admin](https://github.com/MuhammedFaseenCM/winklo-admin) repo, where a Worker cron fills any missing day from UTC today to two days ahead. Since 10 October it makes only hard puzzles, starting with 11 October's: Zip 8×8, Sudoku 6×6, and 6×6 Path Words boards built in code from words the AI suggests (or from a built-in list). Validators check every board, and the cron only creates missing days, so a day's board is never replaced. A board saved by hand in the admin CMS is locked, so the cron never overwrites it.

Reopening a cleared game shows its board read-only with a summary underneath: "Cleared in 1:12 · #4 today · Hint-free" (the rank from that day's board, left out when you're signed out, offline or outside the top 50), the countdown to the next puzzle and a **Full board** link.

The clock pauses when you leave a game and the run is saved on the phone, so it survives the app being closed on the same day, and a game left open over midnight can still be finished for its own day. Players are ranked by time only.

### Around the games

- **Home:** a tile per game with "Play today's …" or "Result", the current streak, a snowflake while the streak's freeze is unused (tap it for what it does), "Streak protected" while a freeze covers a missed day, and a leaderboard shortcut. Under the title: "Best 0:48 · Longest streak 14" (the best time over every day on this phone; streaks from 2 days), and once today's puzzle is cleared, "New puzzle in 6h 12m" in place of the tagline. Home reloads just after midnight if it's left open, and the tiles scroll only when they don't fit. Remote Config drives a soft update banner on Home and a full-screen forced update.
- **Results:** the clear time counting up, a "New personal best" badge when the time beats every earlier day, a streak badge with the longest streak, "New puzzle in 6h 12m" (counted from the run's own day, so a run finished after midnight says a new puzzle is ready), and a mini daily leaderboard (the top 3 plus the two players above and below you). Under the board: "Play … next" for the next daily not cleared today, in Home's order (or "Perfect day!" once all three are done), then one row with **Share** (a spoiler-free text with the day, time, streak and clean-run chips, plus the landing-page link), **Full board** and a home button, kept to about 104 dp so the board keeps its rows on a 360×640 phone.
- **Leaderboards:** per game, daily, weekly and all-time (Remote Config `showAllTimeLeaderboard` can hide all-time), readable without signing in. Top 50 by time, updating live, with medals for the top 3. Under the game tabs, a board pill ("Today ▾") opens a sheet with This week, All-time and a Monday-first calendar of the last 14 days; a scope pill ("Everyone ▾", signed in only) opens Everyone, your leagues and Manage leagues. The board is a 48 dp table (# · player · time, or days and total on the weekly board), so about ten rows fit above the nav dock on a 390×800 phone. Daily rows add icons for hint-free, Flawless (Sudoku) and streak (2+ days), and your row is tinted and pinned above the dock when it's off screen.
- **Streaks:** one per game. A single freeze covers one missed day, once.
- **Haptics:** a light tick for each cell traced in Zip and Path Words (the first one too) and each Sudoku digit or note, a stronger one for a found word, a Zip number reached or a completed row, column or box, and the strongest on a win. Ticks closer than 35 ms are dropped, so a fast swipe ripples instead of buzzing.
- **Profile:** a preset or uploaded avatar, display name, a **Your stats** row (per game: clears, streaks, best and average time, the hint-free share, a clear-time histogram, a calendar of cleared days and a 30-day personal-best trend), a **Badges** card (3 of 16, a progress bar, the earned medals in one row and the next badge to chase, e.g. "Next: 7-day Zip streak · 4 of 7 days") that opens `/profile/badges` (a ladder per game: first clear, then 7, 30 and 100 days in a row; and the special badges with how to earn them; new ones are announced once on Results), sound effects and vibration toggles, privacy policy, report an issue, about (app version), sign out and delete account.
- **Accounts and sync:** Google sign-in is required to play. Best times, clean-run flags, hint use, streaks and Zip paths sync to `users/{uid}` (today's and yesterday's results on each sync) and backfill the leaderboards. The sync isn't in a released build yet; see [Project status](#project-status).
- **App opens:** each day the app keeps one record per signed-in player (`daily_activity/{day}/users/{uid}`) and, through `workers/activity`, one per guest install (`…/guests/{installId}`), with the platform, app version and build, the first and last open and how many times it was opened (cold starts, resumes and sign-ins, at most one per 5 minutes). The Ops Console's App opens page lists them per day.
- **Account deletion:** a web page where players sign in with Google, and the account-deletion Worker deletes their account and data straight away. From 1.0.0+15, Profile → Delete account in the app signs out and opens that page in the browser.
- **Notifications:** local reminders at 08:00 ("puzzles are ready") and 20:00 ("streak at risk"), plus the FCM topics `announcements` and `app_updates`.
- **Languages:** English and Malayalam. Settings → Language offers System (the phone's first language the app has, else English), English and മലയാളം. The whole UI, the reminders and the home-screen widget switch at once; Path Words boards, CMS content (Word Match decks, Category Race categories) and player names stay as they are, and the game names Zip, Path Words and Sudoku stay English. Malayalam renders with Noto Sans Malayalam, bundled under `assets/google_fonts/` behind Lexend.
- **More ways to play:** one row under the Home tiles opens a hub (`/more`) with the **archive** (a month calendar per game from 11 October 2026, the first hard daily, to yesterday; a check marks days cleared in the daily or the archive; a day replays in archive mode, where hints cost time as in the dailies), **practice** (endless offline boards from the Dart generators, with New board and free hints) and two **bonus games**, Word Match and Category Race (decks and categories from the CMS, How to play on the first round, a local best). Game routes carry the mode (`/zip?mode=archive&day=2026-10-09`, `/zip?mode=practice`; no mode is the daily). Only dailies touch streaks, leaderboards, `daily_activity`, the daily best, the daily hint count, the reminders and the widget: archive and practice runs keep drafts, hints and bests under mode-first keys (`archive_zip_<day>`, `practice_sudoku`) in a local store the progress sync never sees.

## Project status

As of 15 October 2026. Production review build is **1.0.0+16** (uploaded to the Play production track). Closed testing still had 1.0.0+14 since 7 October; version code 15 was already consumed on Play.

- **Checks:** `flutter analyze` reports only infos (no warnings or errors), and every test passes. CI (`.github/workflows/ci.yml`) runs both, plus the Workers' type checks and tests, on every push to `master` and every pull request.
- **Server side:** Firebase is on the free Spark plan, so there are no Cloud Functions; server work runs in Cloudflare Workers.

### Done and live

- **Account deletion on the web** (9 October): the page on both hosts, the account-deletion Worker, the rules, the privacy policy and the Data safety answers.
- **Daily puzzle auto-generation** in winklo-admin (9 October), **hard only since 10 October** ([Fix first 12](#auto-generated-puzzles)). From 11 October every daily is an 8×8 Zip, a 6×6 Sudoku and a 6×6 Path Words board with a few blank cells; 10 October and earlier keep their easier boards. Zip boards include a `solution`, which hints need.

### In progress: shipping what's finished

Fix first 1–11 and 17–19 are done and tested on three branches, each started from the one before: `fix/privacy-play-policy` (1–4), `fix/gameplay-fairness` (5–8) and `fix/reliability-and-tooling` (9–11 and 17–19). `master` also has work that isn't released: progress sync with leaderboard backfill, the Zip path review, the redrawn icon and muted tap sounds. The steps, in order:

- [x] Deploy the hard daily puzzles (winklo-admin `38c7055`) and rebuild the 11 October boards with them.
- [x] Merge the three branches into `master` (content already on `master`).
- [x] Deploy the Firestore rules for Fix first 3–4 (`firebase deploy --only firestore:rules`, 13 October).
- [x] Deploy the account-deletion Worker for Fix first 2 (`npx wrangler deploy` in `workers/account-deletion`, 13 October).
- [x] Release **1.0.0+16** to the Play production track for review (`fastlane android production`): changelog in `fastlane/metadata/android/en-US/changelogs/16.txt`.
- [ ] In Play Console, paste the updated App access and account-deletion answers from `play/app_content_answers.txt` (Sudoku needs sign-in too, and the app now has Delete account), and check the store listing against `play/store-media/README.md`. Confirm the production release is in review / approved.
- [ ] Change the GitHub repo description, which still says "Daily Zip path-puzzle game…". Only the repo owner can.

### Ready to merge: `feat/quick-wins`

Started from `master` at `8ebb8d1`; not merged and not uploaded. It holds [Fix first](#fix-first) 13–16 and three [quick wins](#quick-wins-the-data-is-already-there) (3 sharing, 5 "play the next game", 8 the analytics gaps), and prepares **1.0.0+17** (`pubspec.yaml` and `changelogs/17.txt`). It adds `share_plus`. To ship it:

- [ ] Merge `feat/quick-wins` into `master`.
- [ ] Build and upload 1.0.0+17 with fastlane once 1.0.0+16's review allows (`fastlane android production`, or `fastlane android testing` first).

### Ready to merge: `feat/home-review-haptics`

Started from `feat/quick-wins` at `e4b3f2b`, so it holds that branch too; not merged and not uploaded. It adds four [quick wins](#quick-wins-the-data-is-already-there): 1 (bests, longest streak and freezes on Home), 2 (the countdown on Home and Results, and Home's midnight reload), 4 (the summary when a cleared game is reopened) and 6 (haptics, with a Vibration switch in Profile). Along the way it fixes Home overflowing a 520 dp screen and Results clipping its header on a 412 dp phone; on screens too short for both (a phone turned sideways, split screen) the whole Results page now scrolls instead. It moves the version to **1.0.0+18**; `changelogs/18.txt` covers everything since 1.0.0+16, so it reads right whether or not 1.0.0+17 ships first. To ship it:

- [ ] Merge `feat/quick-wins`, then `feat/home-review-haptics`, into `master` (or this branch alone, which contains both).
- [ ] Build and upload 1.0.0+18 once 1.0.0+16's review allows. If 1.0.0+17 never goes out, nothing is lost: Play version codes only need to go up.

The admin console redesign (`feat/ember-glass-redesign`) is merged into winklo-admin's `main`.

### Ready to merge: `feat/roadmap-batch`

Started from `feat/home-review-haptics` at `8b3daff`, so it holds both branches above; not merged and not uploaded. Built 15–16 October from 33 roadmap ideas (marked **Done** below): the spec is `docs/superpowers/specs/2026-10-15-roadmap-batch-design.md`, with a plan per area in `docs/superpowers/plans/2026-10-15-rb-*.md`. It moves the version to **1.1.0+19** (`changelogs/19.txt`) and adds `in_app_update`, `home_widget` and `flutter_localizations`. Its winklo-admin half is the branch `feat/themes-definitions-weekends` (themes, definitions and weekend boards), not merged. The order matters, because the new build depends on the rules and the Worker:

- [ ] Deploy the Firestore rules and indexes: `firebase deploy --only firestore:rules,firestore:indexes`. This is fair-play phase 1, safe for older builds, and it also accepts the `freezeCount` that +19 writes, so it must go first.
- [ ] Remove stored times under the new minimums: `node tools/purge_fast_leaderboard_times.mjs` (a dry run), then again with `APPLY=1`.
- [ ] Deploy the leaderboard Worker: `cd workers/leaderboard && npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON && npm run deploy` (the service account needs Firestore read and write). Then redeploy account deletion, which now also clears leagues and weekly entries: `cd workers/account-deletion && npm run deploy`.
- [ ] winklo-admin: merge `feat/themes-definitions-weekends` into `main`, which deploys it, and set `WINKLO_ANDROID_NOTIFICATION_CHANNEL_ID` to `winklo_announcements`. Check that the next Path Words day has a `theme` and `definitions`, and the next Saturday's docs have `special: 'weekend'`. A weekend Sudoku can take up to about 6 s of the cron's CPU time.
- [ ] App Links: add `docs/.well-known/assetlinks.json` for package `com.winklo.faseencm` with the SHA-256 of the Play app signing certificate (Play Console → App integrity), so the Pages deploy publishes it with the link pages. No phone was connected to read it from the Play build.
- [ ] Have a native speaker review the Malayalam copy in `lib/core/strings/`.
- [ ] Try on a device: the widget (add it, tap each row, the midnight turnover, dark theme), archive and practice boards from production, a first sync with a long local history (stats and badges), a league invite link, and the update banner's shorter text ("Get the latest fixes and puzzles.").
- [ ] Merge into `master`, then build and upload **1.1.0+19**.
- [ ] Fair-play phase 2, once most players are on +19: set Remote Config `minBuildNumber` to 19, change `directLeaderboardWritesAllowed()` in `firestore/firestore.rules` to `return false;`, update the pin test that expects `true`, and redeploy the rules. Clears that never had a proof (older ones a sync finds on a phone) then stop reaching the board; that's by design, and the sync treats the refusal as final.

### Ready to merge: `feat/hint-time-penalty`

Started from `feat/profile-badges`, which holds `feat/leaderboard-table` and `feat/roadmap-batch`; not merged and not uploaded. It removes the 3-hint cap and charges each hint time instead (see [Leaderboards and competition](#leaderboards-and-competition)). Nothing to deploy: the rules and the leaderboard Worker only see the time and the `usedHints` flag. Merge it after the branches it's built on, and have the two new Malayalam strings (`hintWithCost`, `resultsHintPenalty`) and Sudoku's new How to play sentence checked with the rest of the Malayalam copy.

### Ready to merge: `feat/app-opens-tracking`

Started from `feat/hint-time-penalty`, so it holds every branch above; not merged and not uploaded. The Ops Console's **App opens** now comes only from the app's own `daily_activity` records (no GA4 fallback), and a new console page lists who opened the app each day. The app now records guests too: an install ID (a random UUID kept on the phone) goes to the new `workers/activity` Worker, which rate-limits by IP (by /64 for IPv6), by install ID and by new guests per IP, and writes `daily_activity/{day}/guests/{installId}`. Signed-in records gain `opens`, `appVersion`, `build` and `installId`. The 5-minute throttle is per person and per day, so a sign-in right after a guest open, or the first open after midnight, still counts, and the first ping after a cold start waits (at most 5 s) for Firebase to say who is signed in, so a restoring session isn't counted as a guest. Spec: `docs/superpowers/specs/2026-10-17-app-opens-tracking-design.md`, plans `docs/superpowers/plans/2026-10-17-app-opens-*.md`. Its winklo-admin half is the branch `feat/app-opens-page`, not merged. In order:

- [ ] Deploy the Firestore rules (`firebase deploy --only firestore:rules`). They include `feat/roadmap-batch`'s rules, so this can be that checklist's first step. Older builds keep writing as before; the new build's open records are refused until these rules are live.
- [ ] Deploy the activity Worker: `cd workers/activity && npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON && npm run deploy` (the service account needs Firestore write). Its three rate-limit bindings use `namespace_id` 4101–4103; change them in `wrangler.toml` if the Cloudflare account already uses those numbers.
- [ ] winklo-admin: merge `feat/app-opens-page` into `main`, which deploys the console and the admin-api Worker's new `POST /v1/platform/users/lookup`. It works on existing data straight away; versions, open counts and guests fill in as players update.
- [ ] Merge into `master` after `feat/hint-time-penalty` and ship it in the next build. The privacy policy (`docs/privacy/index.html`) already describes the install ID and guest records; Play Data safety already declares "Device or other IDs" for app functionality and analytics.

### Ready to merge: `feat/landing-live-data`

Started from `feat/roadmap-batch` at `9545081`, because its copy describes 1.1.0 (leagues, archive and practice, badges, the widget, Malayalam); merge it with or after that branch. The spec is `docs/superpowers/specs/2026-10-16-landing-live-data-design.md`.

- The landing page shows today's three boards (drawn from the puzzle docs, without their solutions), the three fastest clears per game with shortened names, how many players cleared each, and the time to the next set. It reads them from `GET /api/today?day=yyyy-MM-dd`, a Pages Function in `workers/site/` that reads Firestore's public data over REST and keeps answers in Cloudflare's cache (5 minutes, puzzles 6 hours), so visits don't spend the app's Spark reads. Without the function (GitHub Pages, a plain static server) the live parts stay hidden.
- Headings use Lexend, the app's font, instead of Syne; wide screens get a real grid instead of a stretched phone column.
- The privacy policy says the website shows shortened names and times.
- [ ] After the merge, the Deploy site workflow publishes `docs/` with the function (it now runs from `workers/site/`). Check `curl -sI "https://winklo.pages.dev/api/today?day=$(date +%F)"`: a second call within 5 minutes should say `x-winklo-cache: hit`.

### Pending

- **winklo-admin `fix/daily-puzzle-follow-ups`** is merged into its `main` (`9fa3cd7`), which deploys the SPA and the Worker. Confirm that Deploy run succeeded in GitHub Actions, then check the next Path Words day the cron creates: `boardSource` should say `ai`, and `generatorMeta.aiWords` says why if it doesn't.
- **The rest of the [feature roadmap](#feature-roadmap)**; [Suggested order](#suggested-order) says where to start.

## Feature roadmap

This roadmap was first written against `489ecff` (2026-10-09) and re-checked claim by claim against `8637d00` (2026-10-10). **Apart from the items marked Done, nothing in this section is built yet.** Each idea notes what already exists that makes it cheaper, and gives a rough size: **S** is a day or less, **M** is 2–5 days, **L** is one to two weeks or more.

How the ideas were chosen:

- They build on the three live games rather than adding new ones. A fourth game, Flow, already has its own spec.
- They favour data and code that already exist. A surprising amount is fetched, stored or written but never shown.
- They keep the landing page's promises: no ads, no clutter, and no timer you didn't ask for.

Jump to: [Fix first](#fix-first) · [Quick wins](#quick-wins-the-data-is-already-there) · [Per game](#per-game-improvements) · [Leaderboards](#leaderboards-and-competition) · [Stats](#stats-history-and-achievements) · [Habit](#habit-and-retention) · [More ways to play](#more-ways-to-play) · [Accessibility](#accessibility-and-settings) · [Platform](#platform-and-growth) · [Housekeeping](#housekeeping) · [Suggested order](#suggested-order)

### Fix first

These are bugs and mismatches found in the code. Most are small and worth landing before new features, starting with the privacy and Play policy group. Items marked **Done** are finished in code; [Project status](#project-status) tracks what has shipped.

#### Privacy and Play policy

All four are done. Item 1 reaches players in 1.0.0+15, and items 2–4 take effect once deployed: `npm run deploy` in `workers/account-deletion` (2) and `firebase deploy --only firestore:rules` (3–4).

1. **Done: "Delete account" in the app.** Google Play requires an in-app path to account deletion. Profile → Delete account confirms, signs the app out (so this phone can't sync the account's progress back after the wipe), then opens `/delete-account/` in the browser, since Google sign-in doesn't work in the privacy WebView.
2. **Done: the deletion Worker deletes everything.** It lists the day documents with `showMissing` (the app writes `…/daily/{dayId}/entries/{uid}` and `daily_activity/{dayId}/users/{uid}` without ever creating the day documents, so a plain list found none), deletes `client_errors` too, and deletes in `batchWrite` calls of 100 to stay well inside the Workers Free plan's 50 subrequests. The Auth user goes last, only after everything else is gone, and anything short of a complete deletion is reported as an error the player can retry. The privacy policy and the deletion page now mention the `deletion_requests` record (uid, email, time, result).
3. **Done: profiles are private.** `users/{uid}`, which holds each phone's push token, is readable only by its owner or an admin. Nothing in the app reads other players' profiles; leaderboard rows carry the public name and photo.
4. **Done: leaderboard rules check identity and time.** `updatedAt`, which breaks ties, must be the write's server time or unchanged; names, photo URLs and avatar ids have length limits; and photos must come from Google or our R2 bucket, so no other server sees who opens the board. The client trims names to 40 characters and drops other photo URLs (`lib/data/leaderboard_identity.dart`), and a test pins the client, the rules and the avatar Worker's host together.

#### Gameplay and fairness

All four are done, and reach players in 1.0.0+15.

5. **Done: a reset keeps the clean-run flags.** Reset (Clear in Zip) still clears the board, but `usedHintsThisRun`, Sudoku's `hadMistakesThisRun`, the clock and the hints spent all carry on, so a run that used hints can't earn "Hint-free" (or "Flawless") back. The flags were already saved with the draft.
6. **Done: "New personal best" means beating earlier days.** `IsNewPersonalBest` compares the clear with the best time on every earlier daily of that game stored on the phone (`ScoreRepository.getBestDailyTimeSeconds`), so a first clear or a slower day no longer shows the badge. The Home quick win can reuse it for a lifetime best.
7. **Done: Sudoku hints point out mistakes first.** If a filled cell disagrees with the solution, the hint shades that row and says one of its digits is wrong (it costs a hint, like any other), and clears once the row is fixed. Only then does the coach teach a step.
8. **Done: a run left open over midnight finishes for its own day.** Coming back to a paused run the next day resumes it instead of discarding it, and it still posts to that day's board and streak. Only a run older than that gives way to today's puzzle. Hints are now counted per run (`HintQuotaRepository` takes the run's `playId`), so crossing midnight no longer brings three fresh hints or spends tomorrow's. A run whose app was closed overnight still starts fresh, since Home opens today's puzzle.

#### Reliability

All three are done, and reach players in 1.0.0+15.

9. **Done: the streak reminder no longer skips the day it matters.** With every game cleared, the 20:00 reminder now moves to tomorrow evening instead of being cancelled, so it still comes on a day the app isn't opened. It's a one-off: the notifications plugin fires a daily repeat at the next matching time, which would be tonight.
10. **Done: daily puzzles wait for slow connections.** All three loaders give the server 8 seconds (`dailyPuzzleServerTimeout`), then use the copy cached on the phone (`getDocPreferringServer` in `lib/core/firebase/firestore_read.dart`). They still fail when the puzzle was never cached.
11. **Done: phone photos work as avatars.** The picker scales photos to at most 512 px and re-encodes them as JPEG at quality 85, far below the 2 MiB limit, and a file that is still too large gets a clear message instead of "Could not update profile."

#### Auto-generated puzzles

Item 12 is live. Items 13–15 are done in the app on `feat/quick-wins`; the follow-ups after them aren't started.

12. **Done, live since 10 October: daily puzzles are hard only.** Every daily from 11 October is the hardest tier ('hard', shown as Hard in the app) at the largest size the app plays: Zip 8×8, Sudoku 6×6 with 8–9 givens, and Path Words 6×6. Path Words boards are built in code: one random path through all 36 cells, cut into five or six 5–6 letter words with 3–6 blank cells scattered between them. Blanks never touch each other and every word touches at least two others, so no word stands alone; every word turns, and each can be traced only one way. The AI now only suggests unrelated, letter-sharing words (it couldn't reliably write whole boards), with a built-in list of about 300 words as the fallback. Generation takes a few milliseconds. It shipped from winklo-admin `38c7055`, and the 11 October boards were rebuilt with it. The cron also writes each day create-only now, so two overlapping runs can't give one day two different boards.
13. **Done: Sudoku boards the app can't play are rejected.** `SudokuPuzzle.fromJson` accepts only 6×6 boards with 2×3 boxes (a 9×9 could never be finished, since the keypad stops at 6); any other shape throws `UnsupportedPuzzle`, and the game says the puzzle needs a newer version of the app, with Back home instead of Retry. Broken data in the right shape (grids that aren't 36 cells, givens that disagree with the solution, a solution that isn't a valid Sudoku) shows the usual load error. Since item 12 the generator only makes 6×6 boards, and every board from 7 to 16 October passes these checks.
14. **Done: a replaced board drops the runs saved on the old one.** Each puzzle has a `fingerprint` (FNV-1a over what's on the board, not the doc id), saved runs store it, and each game starts the board and clock fresh when it no longer matches, keeping the run's hint and mistake flags as a reset does. Runs saved by 1.0.0+16 and earlier have no fingerprint and are still restored, so updating mid-run keeps the run. Times from both boards still share that day's leaderboard, and because the app uses the phone's date, a day goes live at the first midnight on Earth (10:00 UTC the day before, at UTC+14) and stays open until 12:00 UTC the day after, so only replace a board before it goes live.
15. **Done: Path Words accepts a word traced along another route.** `PathWordsRules.completedTarget` still prefers the stored path, but now also accepts any route that spells a remaining word and stays off every other word's cells (taking those would leave that word impossible to trace). Found words are drawn where the player traced them. Since item 12 the generator rejects boards with two routes for a word; this covers hand-made ones.

Follow-ups in winklo-admin, all done on its branch `fix/daily-puzzle-follow-ups` (not merged):

- **Done: the AI's words reach the boards.** Every hard Path Words board so far says `boardSource: local`. The Worker only read a reply whose `response` was JSON text; a parsed object, a `choices` list, nested words or a cut-off reply all became zero words, silently. It now reads every reply shape, asks for JSON with a schema from `@cf/meta/llama-3.3-70b-instruct-fp8-fast` (the 3B model couldn't, and misspelled), times out after 30 s, and records why words were dropped in the daily's `generatorMeta.aiWords` and a `path_words_ai_words` log line. Which shape production actually sent isn't confirmed; the Worker's logs weren't kept.
- **Done: Generate never makes the old boards.** A failed call shows "Couldn't generate a board" with Try again, and the in-browser generator is deleted.
- **Done: a live day is locked.** From 10:00 UTC the day before (`daily_live.ts`, shared by the Worker and the CMS), the admin API refuses to change or delete that day's board (409 `day_live`), and the CMS shows it read-only with a Live badge. A live day with no board can still be filled.
- **Done: type check before deploying.** Both `colorIndex` errors were real (stored JSON can lack it), and the deploy workflow now type-checks and tests the SPA and the Worker before either deploys.

#### Copy and tooling

Items 16–19 are done. 17–19 are on `master` (17 reached players in 1.0.0+16) and 16 is on `feat/quick-wins`. The repo description still needs changing by hand.

16. **Done: Sudoku's "How to play" matches the game and opens on the first run.** It describes free entry, the lit-up wrong rows, columns and boxes, and hints that point out a wrong digit or teach a step. It opens once on a player's first Sudoku (`TutorialRepository`, like the other games), with the clock paused while it's open; the **?** button still opens it.
17. **Done: the 08:00 reminder names all three games.** "Play Zip, Path Words and Sudoku to keep your streaks going."
18. **Done: public copy matches the app.** The landing page no longer promises Undo; the store-media brief, `pubspec.yaml`, the privacy page, `play/app_content_answers.txt` and `FIREBASE.md` describe the 6×6 Sudoku, the three games, R2 presets, resized JPEG photos, Sudoku's sign-in and the Firestore-only puzzles. Still to do by hand: the GitHub repo description ("Daily Zip path-puzzle game…") needs the repo owner (`gh repo edit MuhammedFaseenCM/winklo --description "…"` or the repo's About settings).
19. **Done: CI runs every check.** `.github/workflows/ci.yml` runs `flutter analyze --no-fatal-infos` and `flutter test`, and each Worker's type check and `npm test`, on every push to `master` and every pull request, with all actions pinned to commit SHAs (the Pages deploy too). The two stale tests are fixed, and so is a flaky one: the Path Words and Sudoku generators seeded with `Object.hash`, which Dart randomizes per run, so "the same puzzle every day" wasn't; they now use a stable FNV-1a seed (`lib/domain/stable_seed.dart`).

### Quick wins: the data is already there

1. **Done: the longest streak and freezes on Home.** Each tile shows "Best 0:48 · Longest streak 14" under its title, the best time over every day on this phone (`GetBestDailyTimeSeconds`), and a snowflake while the streak's one freeze is unused. Results says "Longest streak 14" too, instead of "Best: 14".
2. **Done: countdown to the next puzzle.** "New puzzle in 6h 12m" on cleared tiles, on Results and under a reopened clear (`NextPuzzleCountdown`, from `PlayPeriod.nextStart`). Home reloads just after midnight while it stays open (`HomeCubit`'s rollover timer, which replaced the debug minute mode's polling).
3. **Done: share your result.** Results has a Share button that sends `Winklo Zip · 9 Oct`, `⏱ 1:12 · 🔥 5 · Hint-free` and the landing-page link through the system share sheet, using the leaderboard's chip rules (Flawless for Sudoku, streaks from 2 days). It sits behind `ShareRepository` (`share_plus`). An image card or a replay of the Zip path can come later.
4. **Done: your result in review mode.** A reopened clear shows "Cleared in 1:12 · #4 today · Hint-free" under the board, with the countdown and a Full board link (`ClearedSummaryCard`). It sits where the controls were, so the board keeps its size, and replaces Sudoku's "Come back tomorrow". The rank needs the player in that day's top 50, the only part of the board the app loads.
5. **Done: "play the next game" on Results.** The daily Results lead with "Play Path Words next": the next game in Home's order (wrapping round) not cleared today, from `NextUnclearedDaily`, or "Perfect day!" once all three are done. The old "Next puzzle" button and `nextLevelId` still only serve the hidden legacy games.
6. **Done: haptics.** `HapticsService` gives a tick per cell traced or digit or note placed, a stronger one for a found word, a Zip number reached or a completed row, column or box, and the strongest on a win. Profile has a Vibration switch (on by default), which the tap on Results follows too.
7. **Ask for a review at a good moment.** After a personal best or a 7-day streak, show Play's in-app review prompt (`in_app_review`). **S**
8. **Done: fill the analytics gaps.** `game_started` and `game_completed` carry `day_id`, and `resumed` or `used_hints` (as 1/0), so each day's start-to-clear rate can be compared before and after the hard-only dailies. New events: `login`, `share`, `notification_opened`, `update_prompt_shown` and `update_prompt_accepted` (soft banner and forced screen, once per appearance), `profile_name_changed`, `profile_avatar_changed` and `streak_freeze_used`, and `results_action` now fires for the dailies (`play_next`, `share`, `leaderboard`, `home`).

### Per-game improvements

#### Zip

- **Done: replay your path.** In review mode a Replay button redraws the saved path of your best run in the order you drew it, about 12 cells a second (`ZipReplayCubit`). It's hidden when there's no saved path.
- **Feedback at each number.** The haptic is done (quick win 6); a soft sound when the path reaches the next number isn't. (Reject sounds for illegal moves were removed on purpose in `6d243ae`.) **S**
- **Compare with the setter's path.** Add a review toggle that overlays the stored `solution`, since many boards have more than one answer. **S**
- **Done: even harder weekends.** `dailyPuzzleParams(game, dateId)` in winklo-admin (`feat/themes-definitions-weekends`) gives Saturdays and Sundays 4–5 numbers and 22–26 walls on the 8×8 board (weekdays 6–7 and 16–20), and the doc gets `special: 'weekend'`, which the app shows as a "Weekend special" badge.
- **Make sure every level has a `solution`.** Hints are disabled when it's missing. Generated boards include one, but the sample level in `FIREBASE.md` doesn't, so check any board made by hand. **S** (content check)

#### Path Words

- **Done: lock found words.** Undo shortens the stroke being drawn or removes the last wrong stroke; a found word stays (Reset still clears everything), and Undo is off when there's nothing it can take back.
- **Done: daily theme.** The winklo-admin cron asks the AI for a short theme and words on it; the doc's `theme` is set only when every word is the AI's. Results and review mode show "Today: Kitchen tools" after the clear, never before. The CMS editor can change it.
- **Done: word definitions.** Each target word comes with a one-line definition in the doc's `definitions` (the AI's, or the built-in list's; every built-in word has one). After a clear, tapping a found word on Results or in review mode opens it in a sheet. They come with the puzzle doc, so Firestore's cache keeps them.
- **Done: bonus words.** `assets/words/en_bonus_words.txt` (public-domain ENABLE, 4–8 letters, slurs and profanity removed; it replaced `en_words.txt`) loads lazily behind `WordListRepository`. A stroke that spells a word from it, isn't a target and isn't a bonus already shows "Bonus word: STARE" and clears without counting as wrong. Bonus words are saved with the draft and the clear meta, and Results shows "3 bonus words"; they don't touch the time, the leaderboard or the clean-run flags.

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
- **Done: past days' boards.** The board sheet's calendar holds the last 14 days; past days are read-only, from the same `watchBoard(dayId:)`.
- **Hint-free filter.** Entries already store `usedHints` (for the best-time run), so a toggle can rank only clean runs. It needs a composite index; since Fix first 5 the flag can be trusted. **S–M**
- **Done: weekly board.** "This week" (in the board sheet) ranks by days cleared, then total time, in Days and Total columns. Entries live at `leaderboards/{game}/weekly/{yyyy-Www}/entries/{uid}`, and only the leaderboard Worker writes them, on each accepted submission, so there's no cron. Release root only: debug builds show the tab empty.
- **Done: tap a player.** A sheet with the avatar, name, time, clean-run chips and streak, all from the entry. The Worker caps the streak at the player's synced streak + 1, but that synced streak is still the player's own `game_streaks` doc.
- **Report a player.** Names and uploaded photos are shown to every player, with no way to report or hide one, and the avatar Worker checks only the declared type and the size. Google Play's user-generated content policy expects in-app reporting and blocking. Add "Report" to leaderboard rows, check the JPEG bytes in the Worker, and keep a way to reset a name or photo. **S–M**
- **Done: friends and private leagues.** Create a league (up to 30 members), share `winklo.pages.dev/join/CODE`, join with the code, leave; the owner renames it, removes members or deletes it. The leaderboard's scope picker shows Everyone or a league, and a league's daily, weekly and past-day boards are its members' entries (one `whereIn` read, ranked on the phone). The rules are tested on the emulator (`firestore/rules_test`, `npm run test:emulator`; not in CI, which has no Java). Account deletion removes the player from leagues and deletes the ones they own. A removed member can rejoin with the same code until the league is deleted.
- **Done: hints cost time instead of running out.** The 3-hint cap is gone. In dailies and the archive the nth hint of a run adds `min(10 × n, 60)` seconds to the run clock (`HintPenalty` in `lib/domain/hint_penalty.dart`), so a hinted clear can't outrank a clean one and a stuck player can still finish. The hint button shows the next cost ("Hint +20s"), Results says "Includes +30s from hints", and practice hints stay free. The time goes into the clock itself, so the draft, points, bests, the leaderboard time and the weekly total all include it; a fresh run with hints already counted for its day (a replaced board, another phone) starts with their time. A hint that would show nothing new is never offered, hint taps are handled one at a time, and asking Sudoku again for the same help on an unchanged grid is free. Results reports the time the run was actually charged, saved with the draft. Spec: `docs/superpowers/specs/2026-10-17-hint-time-penalty-design.md`.
- **Done: fair play, staged.** Submissions go through `workers/leaderboard` (`POST /v1/submit`), which checks the ID token, that the day is live, a minimum time (Zip 10 s, Path Words and Sudoku 15 s) and a proof that solves that day's board (Zip's path, Sudoku's grid, Path Words' strokes), then writes the daily, all-time and weekly entries. Each clear's proof is kept on the phone (`clear_proof_{modeKey}`) so a sync can resend it. When the Worker can't be reached the app falls back to the old direct write, and the board is hidden while a run is paused. Phase 1 rules add the minimum time and a live-day check to direct writes and refuse reads of dailies before they go live; phase 2 turns direct writes off (see [Project status](#project-status)). Limits: a proof only shows the player had the puzzle, the clean-run flags are self-reported, and the streak cap trusts `game_streaks.current`.

### Stats, history and achievements

- **Done: stats screen.** Profile → Your stats opens `/profile/stats`, a tab per game: clears, current and longest streak, best and average time, the share of hint-free clears, a time histogram and a calendar of cleared days. It reads `users/{uid}/game_days` merged with the phone's history, which the first signed-in sync after the update uploads once (`history_uploaded_{uid}`). Each open reads the whole `game_days` collection once, so watch the Firestore read counts.
- **Done: achievements.** 16 badges, summed up on Profile and listed on `/profile/badges` (first clear, 7/30/100-day streaks per game, a Zip under a minute, a week without hints, ten flawless Sudokus, a perfect day), computed in `domain/achievements/`, with a banner on Results for new ones. On a new phone or account, badges already earned are announced once.
- **Done: personal-best trend.** A line of the last 30 days' clear times with the running best, on the stats screen.
- **Done: today's summary on Home.** "2 of 3 cleared · 3:41 total" above the tiles, with a Perfect day badge.

### Habit and retention

- **Done: earn freezes back.** A clear that brings a streak to a multiple of 7 earns a freeze, up to two (`GameStreak.freezeCount`, synced and accepted by the rules); `freezeAvailable` is still written, as `freezeCount > 0`, for older builds. Home shows the count and says once when a freeze saved a streak.
- **Done: smarter reminders.** The evening reminder names the longest streak at risk ("Your 12-day Zip streak ends at midnight") and isn't sent when no streak is at stake. Settings sets both times and turns each type on or off (daily ready, streak at risk, weekly recap, announcements). Reminders and announcements have their own Android channels (`winklo_reminders`, `winklo_announcements`). The streak reminder is now a one-off for tonight and tomorrow evening, replanned on each open, clear and midnight, since its text names a streak.
- **Done: home-screen widget.** An Android widget (`home_widget`, Kotlin RemoteViews) shows each game's ✓ or streak and opens the game through `winkloapp://play/{game}`. It refreshes on app open, each clear, midnight and every 30 minutes.
- **Done: weekly recap.** A Sunday notification ("This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak") and a Home card on Sunday and Monday that can be dismissed for the week. A week with no clears sends nothing.
- **Done: snooze the update banner.** Its close button hides it for 24 hours; the forced screen can't be snoozed.

### More ways to play

- **Done: archive.** Any past daily from 11 October 2026 to yesterday, from the More ways to play hub, in an archive mode that skips streaks, boards and the daily best and keeps its own best time and hint count per run. The date bugs are fixed: Zip's clock no longer stays at 0 for a given date, and Path Words and Sudoku no longer jump to today on resume. Archive days are always read as calendar days, so debug builds with the minute period read the real past dailies.
- **Done: practice mode.** Endless offline boards from `DailyPuzzleGenerator.practice`, `SudokuGenerator.practice` and `PathWordsGenerator.practice`, brought up to the cron's hard rules (Zip 8×8 with 6–7 numbers and 16–20 walls; Sudoku 8–9 unique givens; Path Words 6×6 with 5–6 letter words, lone blanks and one route per word). Path Words practice words come from `assets/words/en_practice_words.txt`, the cron's fallback pool. A practice board's seed is kept in its draft, so leaving and coming back finds it; New board starts another. No leaderboard or streak, and hints are free.
- **Done: weekend specials.** Harder boards at the weekday size on Saturdays and Sundays (by the dateId's calendar date), so older builds can play them: Zip with fewer numbers and more walls, Sudoku with exactly 8 givens, Path Words with five 6-letter words and 6 blanks. The doc's `special: 'weekend'` puts a badge on the Home tiles and the game header. (The 9×9 Sudoku idea is separate.)
- **Done: offline safety net.** Once tomorrow's dailies are live (10:00 UTC the day before), Home reads all three so Firestore caches them; a refused or offline read is tried again after 10 minutes. Since Fix first 10, a slow connection falls back to the cached copy.
- **Done: Word Match and Category Race as bonus games.** In the hub's Bonus games section, with How to play on the first round, sfx and haptics, the app's header and theme, and the shared local-best Results page (best time per deck, most words per category). Their content still comes from the CMS decks.

### Accessibility and settings

- **Done: a settings screen.** Profile → Settings (`/profile/settings`): sound, vibration, the reminders above and the language. An on-screen timer and reduced motion are separate ideas below.
- **Optional visible timer.** A running clock exists but only shows in debug builds (`DevRunTimerLabel`). Offer it as an opt-in setting, in keeping with "no timer you didn't ask for". **S**
- **Respect the system font size.** `AppTextScale` turns off OS text scaling for the whole app so layouts stay fixed. Allow scaling up to about 1.3× outside the boards, which means replacing that app-wide wrapper. **S–M**
- **Reduced motion.** Respect the system "remove animations" setting for the ember burst, sparks and shimmer. **S**
- **Screen readers.** The Flame boards expose nothing to TalkBack. Add a semantics layer that describes the cells, starting with Sudoku, where it's easiest. **M–L**
- **Colour-blind-friendly palette.** Path Words and Sudoku rely on colour: strokes differ only by hue (and wrong strokes look like found words), and Sudoku marks errors with a rose tint next to teal hint shading. Add patterns or outlines, or a high-contrast palette. **M**

### Platform and growth

- **Done: links that open the game.** App Links for `winklo.pages.dev/zip`, `/path-words`, `/sudoku`, `/leaderboard` and `/join/{code}`, with pages in `docs/` for people without the app; shared results link to their game. Back from a page a link, notification or the widget opened goes Home. Verification needs `docs/.well-known/assetlinks.json` with the Play signing certificate (see [Project status](#project-status)).
- **Done: Play in-app updates.** The soft banner starts a flexible update and then offers "Restart to update"; the forced screen starts an immediate one. Both fall back to the store page (`in_app_update`).
- **iOS.** There's no `ios/` folder yet, and `firebase_options.dart` throws on iOS. It needs a Firebase iOS app, APNs for push and the Google Sign-In URL scheme. App Store rules will likely require Sign in with Apple, and they require account deletion inside the app (guideline 5.1.1(v)); the deletion Worker already accepts any Firebase sign-in. **L**
- **Done: Malayalam.** All copy goes through `AppStrings`, which stays plain Dart because notifications, the widget and issue reports read it without a `BuildContext`: each member reads the current table, `AppTextEn` or `AppTextMl` (both implement `AppText` in full, so a missing string doesn't compile). `LocaleCubit` (Settings → Language, stored in shared_preferences) switches the table and the `MaterialApp` locale together, rebuilds the app with its state kept, and replans the reminders and the widget. Dates in the calendars and time pickers come from the Material localizations; Western digits throughout. **The Malayalam copy was written without a native speaker and needs a native speaker's review before release** (`lib/core/strings/app_text_ml.dart`; `test/features/l10n/malayalam_screens_test.dart` with `WINKLO_SCREENSHOTS=1` writes screenshots of every main screen to check lengths). Another language is another `AppText` table plus its code in `AppStrings.supportedLanguageCodes` and `AppLanguage`; Path Words would also need word content in that language. **L**
- **Revenue without ads (optional).** If it's ever needed, keep the no-ads promise, for example with a one-time supporter pack that unlocks the archive and extra avatars. **M**

### Housekeeping

These aren't features, but they affect how cheap the ideas above are:

- Settled: practice mode uses the Dart generators (`practice(seed)` in each, following the cron's hard rules). Their older date-seeded `generate`/`forDate` paths still run only in tests, and the rules now live in two languages (winklo-admin's TypeScript and the Dart practice ports), so a change to the cron's hard rules should be mirrored in the practice ports.
- `generate_daily_path_words.dart` and `generate_daily_sudoku.dart` sit in `lib/domain/usecases/` but import `cloud_firestore`, and they fetch rather than generate. Move them behind repositories, as Zip already is, to keep `domain/` pure Dart as CLAUDE.md asks.
- `FetchZipLevels` and the bundled `assets/zip/levels/*` are unreachable. `WordListRepository` serves only the bonus word list; its daily-nouns path and the `path-words-nouns` client are registered but never read, so that Worker is never called.
- Path Words' `hintFlashCell` and Sudoku's `hintFlashIndex` (with its drawing code) are left over from older hints; today's hints are drawn another way.
- The replay fields in `ResultsArgs` are ignored for the dailies, and guest-play code (for example `results_board_tease.dart`) remains from before sign-in became compulsory.
- `SfxService.tapSoundEnabled` is still `false` ("muted for now").

### Already designed elsewhere

- **Flow**, a fourth daily game (draw non-crossing paths between matching pairs), has an approved spec and plan in `docs/superpowers/` but no code. It's out of scope here because it's a new game.
- **Account deletion** (spec and plan dated 2026-10-09) is built and live: the page, the Worker, the rules and the policy updates. Its spec left the in-app button out of v1; it was added afterwards (Fix first 1), along with the Worker fixes in Fix first 2, and both are waiting to ship (see [Project status](#project-status)).
- **Daily puzzle auto-generation** (spec and plan dated 2026-10-09) is built in winklo-admin and needed no app changes. Since 10 October it makes hard puzzles only (the spec's "hard only" update). It changes some of the ideas above: difficulty is now a generator rule, and the generators exist twice (see [Housekeeping](#housekeeping)).
- Ideas the specs deferred are folded into the sections above: profile stats, "you'd be #N", per-type notification toggles, in-app updates and the banner snooze, 9×9 and practice Sudoku, anti-cheat, iOS and localization.

### Suggested order

| Phase | Ideas | Why |
|---|---|---|
| **Now** | Ship `feat/roadmap-batch` (it holds `feat/quick-wins` and `feat/home-review-haptics`) in the order under [Project status](#project-status); the review prompt (quick win 7) | Everything built so far reaches players, and fair play protects the boards |
| **Next** (mostly S–M) | Reporting players (Play's user-generated content policy); fair-play phase 2; Sudoku undo, highlighting, tidy notes and the digit counter; rank beyond the top 50 and percentile; the hint-free filter; the visible timer and reduced motion | Keeps the boards safe and makes Sudoku match the other two games |
| **Later** (mostly L) | Screen-reader support for the boards; a colour-blind-friendly palette; Weekend 9×9 Sudoku; iOS; more languages; Flow | Bigger bets, once the core loop can be measured |

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

**Workers:** in `workers/avatar-upload`, `workers/account-deletion`, `workers/activity` (guests' app opens; needs the `FIREBASE_SERVICE_ACCOUNT_JSON` secret too) or `workers/path-words-nouns`, run `npm test`, `npm run dev` or `npm run deploy`. The account-deletion Worker also needs the `FIREBASE_SERVICE_ACCOUNT_JSON` secret (`npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON`) and shares the `winklo-avatars` R2 bucket with avatar-upload.

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
workers/           Cloudflare Workers: avatar-upload, account-deletion, leaderboard
                   and activity (used), path-words-nouns (unused), and site: the
                   landing page's /api/today Pages Function
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
