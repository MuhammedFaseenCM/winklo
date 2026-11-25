# Levels Intro and Nudges: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lead players into Levels with:
- a one-time "New: Levels" intro card;
- a first-clear tip;
- a Levels card on Home;
- a nudge after a daily clear;
- a dot on the Levels tab.

**Architecture:** A new `LevelsIntroRepository` holds the per-install flags, using SharedPreferences behind a domain interface registered in `core/di`. Each UI piece reads it with `context.read`. The intro and the Home card use the existing `LevelWorldRepository.catalog(game)` and `LevelProgressRepository.progress(game)`, through `LevelMap.build(...).currentId`, to name the next level. Navigation reuses `levelsOpenLocation(id)`, which opens `/levels?open=<id>`.

**Tech stack:** Flutter, Cubit or StatefulWidget, `bloc_test` + `mocktail`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-25-levels-intro-design.md`

## Global Constraints

- Branch `feat/levels-intro`. Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- All copy goes in `AppStrings`, in en and ml, and is added to the sample table in `test/core/strings/app_text_test.dart`.
- `domain/` has no Flutter imports.
- `flutter analyze` stays at the baseline of 20, and the full `flutter test` stays green.
- The Home Levels card is no taller than `HomeMorePlayEntry`.
- Nothing changes on the server or in the admin.

## Review Focus

1. The intro never opens over a game route reached from a notification or deep link, and never while a forced update is showing.
2. The intro shows exactly once, even if the app is killed while it's on screen. The flag is set when it shows.
3. When the catalog is offline, the intro and the Home card still work and fall back to Level 1 or the Levels tab. They never show a spinner forever.
4. The dot clears the first time the Levels tab opens, whether from the dock, the Home card or the intro.
5. A daily result reopened from Home (View result) still shows the nudge. Level, archive and practice results never do.

---

### Task 1: `LevelsIntroRepository` and analytics
- Domain `lib/domain/repositories/levels_intro_repository.dart`:
  ```dart
  abstract class LevelsIntroRepository {
    bool get introSeen;            Future<void> markIntroSeen();
    bool get firstClearTipSeen;    Future<void> markFirstClearTipSeen();
    bool get levelsTabSeen;        Future<void> markLevelsTabSeen();
    String? get lastGame;          Future<void> setLastGame(String gameId); // only levelGameIds
    Stream<void> get changes;
  }
  ```
- Data impl `lib/data/repositories/levels_intro_repository_impl.dart`. Its keys are `levels_intro_seen`, `levels_first_clear_tip_seen`, `levels_tab_seen` and `levels_last_game`. Register it in `app_repositories.dart`.
- `AnalyticsRepository.logLevelsIntro({required String action, String? gameId})`, where `action` is `shown`, `play` or `later`. Implement it in every implementation and fake (grep for `implements AnalyticsRepository`).
- Tests:
  - the impl round-trips each flag;
  - `lastGame` ignores a game that has no Levels;
  - `changes` fires on every write.

### Task 2: `LevelsIntroSheet` and the Home trigger
- Create `lib/features/levels/view/widgets/levels_intro_sheet.dart`, opened with `showLevelsIntro(context)`. It is a modal bottom sheet on the root navigator, with:
  - a title and a sub-line;
  - a row per game (Zip, Path Words), each with a Play button. The label is `AppStrings.levelNumber(n)` for the current level number, or the first level when the map is unknown;
  - "Maybe later".
- Play marks the last game, logs `play`, closes the sheet and runs `context.go(levelsOpenLocation(id))`. If the catalog failed, it runs `context.go(levelsLocation)` with the game preference set to that game.
- Home `_HomeViewState`, in a post-frame callback after the permission prompt: when `!introSeen`, the route path is `/`, and `AppUpdateCubit?.isForced != true`:
  1. `markIntroSeen`;
  2. log `shown`;
  3. `showLevelsIntro`.
- Tests:
  - the sheet lists both games, with "Level 1" when there's no progress and "Level 4" when Path Words has 3 cleared;
  - Play routes to `/levels?open=path_words_1_04` and logs `play`;
  - Maybe later closes the sheet and logs `later`;
  - Home shows it once, not on the second build, and not when the flag is already set.

### Task 3: First-clear tip
- In `LevelResultsView`, while `!firstClearTipSeen`, show a tip card under the goals with `AppStrings.levelsFirstClearTip`, and mark it seen on first build.
- Tests: shown the first time, not the second, and Next level still works.

### Task 4: Home "Levels" card
- Create `lib/features/home/view/widgets/home_levels_entry.dart`, styled like `HomeMorePlayEntry`. It shows:
  - the icon `AppIcons.levels`;
  - the title "Levels";
  - a sub-line with ★ total stars across both games, and "Continue: <Game> Level N".
- Tapping it opens the level sheet for that game and level through `levelsOpenLocation`.
- The game is `lastGame`, else Path Words. It counts stars with `LevelMap.build` for each game, and skips a game whose catalog fails.
- Place it in Home's tiles before `HomeMorePlayEntry`.
- Tests:
  - total stars;
  - the continue target follows `lastGame`;
  - offline it still shows and opens `/levels`;
  - height no taller than `HomeMorePlayEntry` at 360×640.
- The level sheet's Play calls `setLastGame`. Add a test in `level_sheet_test`.

### Task 5: Nudge after a daily clear
- In `_CelebrateAndClaimResults` (results_screen.dart), add a row under the actions: `AppStrings.levelsDailyNudge` plus an arrow, which runs `context.go('/levels')`.
- Tests: a daily result shows it and taps to `/levels`; a level result doesn't show it.

### Task 6: Dot on the Levels tab
- `FloatingNavDock` gets `showLevelsDot` (default false), drawing an ember dot on destination index 1.
- `DashboardShell` passes it from `LevelsIntroRepository.levelsTabSeen`, rebuilding on `changes`.
- `LevelsScreen.initState` calls `markLevelsTabSeen`.
- Tests: the dock draws the dot only when asked; opening `LevelsScreen` marks it seen.

### Task 7: Check on the emulator
- Install with `pm trim-caches` and `adb install -r`. Never uninstall, so the sign-in stays.
- To see the intro, clear just the intro flags with `run-as`, removing the `levels_*` keys from the flutter shared_prefs XML while the app is stopped.
- Walk through:
  - the intro;
  - Play into Path Words;
  - the dot clears;
  - the Home card;
  - the daily results nudge (reopen the result of a cleared daily);
  - the first-clear tip.
