# Winklo

Winklo is a daily solo-puzzle app for Android, built with Flutter and Flame. Every day brings one new puzzle in each of three games — **Zip**, **Path Words** and **Sudoku** — with a live daily leaderboard, a streak per game, and progress that follows your Google account to a new phone.

- **Landing page:** <https://winklo.pages.dev> · **Privacy policy:** <https://winklo.pages.dev/privacy/>
- **Play Store package:** `com.winklo.faseencm`
- **Stack:** Flutter + Flame, BLoC/Cubit, go_router · Firebase (Auth, Firestore, Analytics, Crashlytics, Remote Config, Cloud Messaging) · Cloudflare R2 (images) and Workers (avatar upload)

## Contents

1. [What's in the app today](#whats-in-the-app-today)
2. [Feature roadmap](#feature-roadmap)
3. [Getting started](#getting-started)
4. [Project layout](#project-layout)
5. [More docs](#more-docs)

## What's in the app today

### The three daily games

| | Zip | Path Words | Sudoku |
|---|---|---|---|
| **Goal** | Draw one path through every cell, visiting the numbers in order; walls block moves | Trace each hidden word through a sparse letter grid | Fill a 6×6 grid (2×3 boxes) with 1–6 |
| **Hints** (3 per game per day) | Reveals the next cells of the stored solution | Clears wrong strokes, otherwise reveals the next letter of a word | Explains the next logical step; never fills a cell |
| **Mistakes** | Illegal moves are ignored | Wrong strokes stay on the board, no penalty | Free entry; a filled row, column or box that is wrong lights up |
| **Controls** | Undo, clear | Undo, reset | Notes, erase, reset |
| **First run** | Animated tutorial and rule tips | Animated tutorial and a tip | "How to play" text |
| **After clearing** | Read-only review of the path you drew | Review of the found words | Review of the solved grid |

All three load the day's puzzle from Firestore (`zip_levels`, `path_words_levels`, `sudoku_levels`, doc id `daily_YYYYMMDD`). The puzzles are authored in the separate [winklo-admin](https://github.com/MuhammedFaseenCM/winklo-admin) repo. The clock pauses when you leave a game and the board is saved, so a run survives the app being closed. Players are ranked by time only.

### Around the games

- **Home:** a tile per game with "Play today's …" or "Result", the current streak, "Streak protected" while a freeze covers a missed day, and a leaderboard shortcut. A soft or forced update banner is driven by Remote Config.
- **Results:** the clear time counting up, personal-best and streak badges, and a mini daily leaderboard (the top 3 plus the players around you).
- **Leaderboards:** per game, daily and all-time (Remote Config `showAllTimeLeaderboard` can hide all-time). Top 50 by time, updating live, with "Hint-free", "Flawless" (Sudoku) and streak chips, and medals for the top 3.
- **Streaks:** one per game. A single freeze covers one missed day.
- **Profile:** a preset or uploaded avatar, display name, sound effects toggle, privacy policy, report an issue, and sign out.
- **Accounts and sync:** Google sign-in is required to play. Best times, clean-run flags, hint use, streaks and Zip paths sync to `users/{uid}` and backfill the leaderboards.
- **Notifications:** local reminders at 08:00 ("puzzles are ready") and 20:00 ("streak at risk"), plus the FCM topics `announcements` and `app_updates`.
- **Hidden legacy games:** Word Match and Category Race are still in `lib/features/` and have routes, but nothing in the UI links to them.

## Feature roadmap

This is an analysis of the code at `489ecff` (2026-10-09). **Nothing in this section is built yet.** Each idea notes what already exists that makes it cheaper, and gives a rough size: **S** is a day or less, **M** is 2–5 days, **L** is one to two weeks or more.

How the ideas were chosen:

- They build on the three live games rather than adding new ones. A fourth game, Flow, already has its own spec.
- They favour data and code that already exist. A surprising amount is fetched, stored or written but never shown.
- They keep the landing page's promises: no ads, no clutter, and no timer you didn't ask for.

Jump to: [Fix first](#fix-first) · [Quick wins](#quick-wins-the-data-is-already-there) · [Per game](#per-game-improvements) · [Leaderboards](#leaderboards-and-competition) · [Stats](#stats-history-and-achievements) · [Habit](#habit-and-retention) · [More ways to play](#more-ways-to-play) · [Accessibility](#accessibility-and-settings) · [Platform](#platform-and-growth) · [Housekeeping](#housekeeping) · [Suggested order](#suggested-order)

### Fix first

These are bugs and mismatches found during the analysis. All are small and worth landing before new features.

1. **Reset wipes the clean-run flags.** Reset sets `usedHintsThisRun` back to false in all three games, and `hadMistakesThisRun` in Sudoku. The clock and the day's hint quota carry on, so a run that used hints can still earn the "Hint-free" chip. The timer spec treats a reset as the same run, and the Flow spec says a reset should count against the chip. Fix by keeping the flags for the whole run, or by deriving "used hints" from the day's hint quota, as the sync already does for older clears (`legacyClearFlags`). *Where:* the reset handlers in `zip_bloc.dart`, `path_words_bloc.dart` and `sudoku_bloc.dart`. **S**
2. **Sudoku's "How to play" is out of date.** It still says "Wrong entries are rejected", but free entry shipped in build 13. *Where:* `AppStrings.sudokuHowToPlayBody`. **S**
3. **The 08:00 reminder leaves out Sudoku.** Its text reads "Play Zip and Path Words to keep your streak going." *Where:* `AppStrings.notifDailyReadyBody`. **S**
4. **Most phone photos can't be used as avatars.** The picker doesn't resize or compress, and the upload Worker rejects anything over 2 MiB, which most camera photos exceed. Pass `maxWidth` and `imageQuality` to `pickImage`, or crop to a square first. *Where:* `avatar_edit_sheet.dart`, `r2_avatar_upload_client.dart`. **S**
5. **Account deletion is on the web, not in the app yet.** Users can delete at [winklo.pages.dev/delete-account/](https://winklo.pages.dev/delete-account/) (Google Sign-In, immediate wipe via the account-deletion Worker). Optional follow-up: add a Profile entry point in the app for Play’s in-app expectation. **S**
6. **Public copy has drifted from the app.** **S**
   - The landing page promises Undo, but Sudoku has none (or build it; see [Sudoku](#sudoku)).
   - `play/store-media/README.md` says "Classic 9×9 Sudoku"; the game is 6×6.
   - The `pubspec.yaml` description still lists Word Match and Category Race.
   - The privacy page says preset avatars are bundled with the app; they load from R2.
   - `play/app_content_answers.txt` says only Zip and Path Words need sign-in; Sudoku does too.
   - `FIREBASE.md` says the app works without Firebase; the daily games don't.
7. **Tests don't run in CI.** The only workflow deploys the landing page. Add `flutter analyze` and `flutter test` on pushes and pull requests, and pin `cloudflare/wrangler-action` to a commit SHA. Two tests already fail on `master`: `app_layout_test` ("keeps roomy spacing on design-size phones") and `widget_test` ("Home shows Path Words streak independently of Zip"). **S**

### Quick wins: the data is already there

1. **Show best time and longest streak on Home.** `HomeCubit` already loads the best time, longest streak and freeze status for every game, and `AppStrings.bestTimeLabel` exists, but the tiles only show the current streak. **S**
2. **Countdown to the next puzzle.** Show "New puzzle in 6h 12m" on cleared tiles and on Results. Release builds also don't refresh Home at midnight (only the debug minute mode does), so add a rollover timer. *Builds on:* `PlayPeriod`. **S**
3. **Share your result.** Add a spoiler-free share text on Results, for example `Winklo Zip · 9 Oct · ⏱ 1:12 · 🔥 5 · Hint-free`, with the landing-page link. Sharing is how daily puzzles spread, and the app has no share option anywhere. An image card or a replay of the Zip path can come later. *Builds on:* the Results data, clean-run flags and streaks. Needs `share_plus`. **S**
4. **Show your result in review mode.** Reopening a cleared game shows the board but not how you did. Add a header such as "Cleared in 1:12 · #4 today · Hint-free" with a link to the full board. *Builds on:* the best time and flags in `ScoreRepository`, and the player's leaderboard entry. **S**
5. **"Play the next game" on Results.** Go straight to the next uncleared daily instead of back to Home. The `results_action` analytics event already has a `play_other` value. **S**
6. **Haptics.** The whole app has a single haptic tap, on Results. Add light ticks for each cell, found word and completed row, column or box, and a stronger one on a win, with a setting to turn them off. The `VIBRATE` permission is already declared. **S**
7. **Ask for a review at a good moment.** After a personal best or a 7-day streak, show Play's in-app review prompt (`in_app_review`). **S**
8. **Fill the analytics gaps.** Nothing logs sign-in, sharing, notification opens, update prompts, avatar or name changes, or freeze use, and `results_action` never fires for the three dailies. Without these events you can't measure the effect of anything else on this list. **S**

### Per-game improvements

#### Zip

- **Replay your path.** Since `489ecff` the saved path keeps the order you drew the cells in, so review can animate it being drawn. It would also make a good share clip. **S**
- **Feedback at each number.** Play a soft sound and haptic when the path reaches the next number, and use the unused `reject.ogg` when a move hits a wall. **S**
- **Compare with the setter's path.** Add a review toggle that overlays the stored `solution`, since many boards have more than one answer. **S**
- **Difficulty ramp.** Easier boards early in the week and harder ones at the weekend (bigger grid, fewer numbers, more walls), with a difficulty badge like Sudoku's. This is mostly content work in winklo-admin. **M**
- **Make sure every level has a `solution`.** Hints are disabled when it's missing, and the sample level in `FIREBASE.md` doesn't include one. **S** (content check)

#### Path Words

- **Lock found words.** Undo removes the last stroke even when it was a correct word. Only wrong strokes should be undoable. **S**
- **Draw the hint.** `hintFlashCell` is set but never drawn, so a hint gives less visible feedback than intended. **S**
- **Daily theme.** Make each day's words share a theme that's revealed when you clear the puzzle ("Today: kitchen tools"). The `path-words-nouns` Worker already generates daily word pools with Workers AI. **M**
- **Word definitions.** After clearing, tap a found word to see a one-line definition, cached the same way as the noun pool. **M**
- **Bonus words.** Count real words that aren't targets as bonus finds. This needs a bigger dictionary than the bundled `en_words.txt`. **M**

#### Sudoku

- **Undo.** The landing page promises it, and the other two games have it. **S–M**
- **Highlight related cells.** Shade the selected cell's row, column and box, and every cell with the same digit, as most Sudoku apps do. **S**
- **Tidy notes automatically.** Placing a digit should remove it from the notes in the same row, column and box (as an option). **S**
- **Digit counter.** Show how many of each digit are left on the keypad, and dim the ones that are finished. **S**
- **Draw the hint.** `hintFlashIndex` is never set, so the hint-flash drawing in `sudoku_game.dart` never runs. **S**
- **Animated tutorial.** Zip and Path Words have one; Sudoku only has a text dialog. **S–M**
- **Weekend 9×9.** Offer a bigger board on Saturdays and Sundays (deferred in the 6×6 spec). It needs a layout pass and new content. **L**

### Leaderboards and competition

- **Your rank beyond the top 50.** The board only loads the top 50, so players below that never see their rank. A Firestore `count()` query on faster times gives "You're #132 of 1,204". **S–M**
- **Percentile on Results.** "Faster than 78% of today's players", from the same counts. The post-game spec deferred this as "you'd be #N". **S**
- **Past days' boards.** The repository already takes a `dayId`; add a date picker to the daily board. **S–M**
- **Hint-free filter.** Entries already store `usedHints`, so a toggle can rank only clean runs. It needs a composite index. **S–M**
- **Weekly board.** Rank by total or average time across the week's clears, ideally with a scheduled function that adds up the daily boards. **M–L**
- **Tap a player.** Open a small card with their avatar, name and streak, all of which are already on the entry. **S**
- **Friends and private leagues.** Use invite codes to make a filtered board for friends, family or a team. This needs a small social graph and new rules. **L**
- **Server-side checks.** Add a function that rejects impossible times, such as a few seconds on an 8×8 Zip. The specs deferred this as anti-cheat. **M**

### Stats, history and achievements

- **Stats screen.** Per game: clears, current and longest streak, best and average time, how often you clear without hints, a time histogram and a calendar of cleared days. The history is already synced per day to `users/{uid}/game_days` (time, points, hints, mistakes), and owners can read it. **M**
- **Achievements.** First clear, 7/30/100-day streaks, a Zip under a minute, a week without hints, ten flawless Sudokus, a perfect day with all three cleared. Compute them from the same day records and show them on Profile. **M**
- **Personal-best trend.** A small chart of clear times over the last 30 days. **S** once the stats screen exists.
- **Today's summary on Home.** "2 of 3 cleared · 3:41 total", with a "Perfect day" badge when all three are done. **S**

### Habit and retention

- **Earn freezes back.** Today each game gets one freeze for good: once it's used, nothing makes it available again. Earn one for each 7-day streak (up to two, say), show the count on Home, and tell players when a freeze saved their streak. `GameStreak.freezeAvailable` would become a count, so the streak sync and its rules change too. **M**
- **Smarter reminders.** The 20:00 reminder is scheduled whenever any game is uncleared, even when no streak is at stake, and its text is generic. Name the streak at risk ("Your 12-day Zip streak ends at midnight"), skip the reminder when there is nothing to lose, and let players choose the time and which reminders they get (per-type toggles were deferred in the notifications spec). **M**
- **Home-screen widget.** Show today's status for each game, the streak and the countdown, and open straight into a game. **M–L**
- **Weekly recap.** A Sunday notification or Home card: "This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak". **M**
- **Snooze the update banner.** The soft update banner can't be dismissed; let players hide it for a day (deferred in the force-update spec). **S**

### More ways to play

- **Archive.** Let players play any past day's puzzle. Past dailies should still be in Firestore under their `daily_YYYYMMDD` ids, as long as winklo-admin keeps them, and all three game screens already accept a `date`. Archive runs wouldn't touch streaks or the daily board, but could keep their own best time. **M**
- **Practice mode.** Offer endless offline puzzles from the generators already in the repo (`DailyPuzzleGenerator`, `PathWordsGenerator`, `SudokuGenerator`), which are only used by tests today. No leaderboard or streak. **M**
- **Weekend specials.** A bigger or themed board on Saturday and Sunday for each game (see the Zip difficulty ramp and the Sudoku 9×9 idea). **M–L**
- **Offline safety net.** If Firestore can't be reached and today's puzzle isn't cached, the game only shows an error. Puzzles are already published 1–2 days ahead (see `FIREBASE.md`), so the app can prefetch tomorrow's while online. **S–M**
- **Word Match and Category Race.** Both still work and are routed, but earlier specs parked them on purpose ("not as dailies"). Only bring them back as bonus games, with the same polish as the dailies. **L**

### Accessibility and settings

- **A settings screen.** Today only sound has a toggle. Put sound, haptics, reminders, an optional on-screen timer and reduced motion in one place. **M**
- **Optional visible timer.** A running clock exists but only shows in debug builds (`DevRunTimerLabel`). Offer it as an opt-in setting, in keeping with "no timer you didn't ask for". **S**
- **Respect the system font size.** `AppTextScale` turns off OS text scaling so layouts stay fixed. Allow scaling up to about 1.3× outside the boards. **S–M**
- **Reduced motion.** Respect the system "remove animations" setting for the ember burst, sparks and shimmer. **S**
- **Screen readers.** The Flame boards expose nothing to TalkBack. Add a semantics layer that describes the cells, starting with Sudoku, where it's easiest. **M–L**
- **Colour-blind-friendly palette.** Path Words and the Zip path rely on colour. Add a high-contrast palette or patterns. **M**

### Platform and growth

- **Links that open the game.** Add App Links for `winklo.pages.dev/zip` and similar (with `assetlinks.json` on Pages), so shared results and announcements open the right screen. The app only declares a launcher intent filter today. **M**
- **Play in-app updates.** Use Play's in-app update API instead of sending players to the store page (deferred in the force-update spec). **S–M**
- **iOS.** Flutter makes this mostly a build and store project, but App Store rules will likely require Sign in with Apple (or a similar privacy-focused login) alongside Google. **L**
- **Other languages.** All UI text is already in `AppStrings`, which makes a move to ARB files straightforward. Path Words would also need word content in each language. **L**
- **Revenue without ads (optional).** If it's ever needed, keep the no-ads promise, for example with a one-time supporter pack that unlocks the archive and extra avatars. **M**

### Housekeeping

These aren't features, but they affect how cheap the ideas above are:

- The three puzzle generators run only in tests. Reuse them for practice mode, or delete them.
- `FetchZipLevels` and `assets/zip/levels/*` are unreachable. `WordListRepository` and the `path-words-nouns` Worker are registered but unused (the daily-theme idea could use the Worker).
- The replay fields in `ResultsArgs` are ignored for the dailies.
- `SfxService.tapSoundEnabled` is still `false` ("muted for now").

### Already designed elsewhere

- **Flow**, a fourth daily game (draw non-crossing paths between matching pairs), has an approved spec and plan in `docs/superpowers/` but no code. It's out of scope here because it's a new game.
- Ideas the specs deferred are folded into the sections above: profile stats, "you'd be #N", per-type notification toggles, in-app updates and the banner snooze, 9×9 and practice Sudoku, account deletion, anti-cheat, iOS and localization.

### Suggested order

| Phase | Ideas | Why |
|---|---|---|
| **Now** (about a week, mostly S) | Everything in [Fix first](#fix-first); best time and countdown on Home; sharing; the review header; "play the next game"; haptics; the analytics gaps | Fixes the fairness and Play-policy issues, adds the main growth lever, and makes later changes measurable |
| **Next** (2–4 weeks, mostly M) | Sudoku undo and highlighting; earning freezes back; smarter reminders and a settings screen; rank beyond the top 50 and percentile; past days' boards; the stats screen | Strengthens the daily habit and gives players more reasons to come back |
| **Later** (mostly L) | Archive; practice mode; achievements; weekend specials; home-screen widget; App Links; friends leagues; screen-reader support for the boards; iOS; other languages | Bigger bets, once the core loop can be measured |

## Getting started

**Requirements:** Flutter with Dart `^3.12.1`, the Android SDK, and access to the Firebase project `brain-zip-app`. `android/app/google-services.json` and `lib/firebase_options.dart` are committed.

```bash
flutter pub get
flutter run --dart-define=DAILY_PLAY_PERIOD=true
```

- **`DAILY_PLAY_PERIOD=true`** makes a debug build use calendar days, like release. Without it, a debug build looks for a new puzzle every minute; those docs usually don't exist, so you get "Could not load today's puzzle". The VS Code launch config already passes the flag.
- **Sign-in:** playing needs Google sign-in, so your debug key's SHA-1 must be registered on the Firebase Android app.
- **Debug data is separate:** debug builds read and write `leaderboards_debug` and `users/{uid}/game_days_debug` / `game_streaks_debug`, never the production collections.
- **Other build flags** have production defaults: `STATIC_ASSETS_BASE_URL` (R2 images), `AVATAR_UPLOAD_BASE_URL` (the photo upload Worker; empty disables uploads) and `PATH_WORDS_NOUNS_BASE_URL` (unused).

**Checks**

```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # after changing freezed classes; generated files are committed
```

**Firebase rules:** `firebase deploy --only firestore:rules`. Deploy the rules **before** shipping a build that writes a new Firestore key; see [FIREBASE.md](FIREBASE.md).

**Release:** signing reads `android/key.properties`, which isn't committed. Build with `flutter build appbundle`, then upload with fastlane: `fastlane internal`, `fastlane closed` (the alpha track) or `fastlane testing` (both). `fastlane listing` and `play/upload_listing.py` update the store listing, and `play/upload_data_safety.py` updates the Data safety form.

**Workers:** in `workers/avatar-upload` or `workers/path-words-nouns`, run `npm test`, `npm run dev` or `npm run deploy`.

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
workers/           Cloudflare Workers: avatar-upload (used), path-words-nouns (unused)
tool/, tools/      icon and avatar generators, demo leaderboard seeding, R2 source art
play/, fastlane/   Play listing, Data safety and release lanes
docs/              landing page and privacy policy (deployed to Cloudflare Pages);
                   docs/superpowers/ holds design specs and plans
```

The architecture rules (feature-first folders, the domain/data split, Cubit or Bloc, DI) are in [CLAUDE.md](CLAUDE.md).

## More docs

- [FIREBASE.md](FIREBASE.md): Firebase setup, collections, security rules, Remote Config and notifications
- [CLAUDE.md](CLAUDE.md): architecture and conventions
- [docs/superpowers/specs/](docs/superpowers/specs/): design specs, with matching plans in `docs/superpowers/plans/`
