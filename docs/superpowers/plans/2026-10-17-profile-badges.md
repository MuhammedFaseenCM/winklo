# Profile Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Profile shows a compact Badges card instead of the 16-badge grid. The full collection moves to `/profile/badges`. Profile, Stats and Badges scroll clear of the nav dock.

**Architecture:**
- A pure `nextAchievement` rule in `domain/achievements/`.
- An `AchievementMedal` widget extracted from the old grid.
- `BadgesSummaryCard` and `BadgesScreen` in `features/achievements/view/`.
- `AppLayout.scrollPadding(context)` for dock clearance.

**Tech Stack:** Flutter, flutter_bloc (`StatsCubit`), go_router, mocktail.

Spec: `docs/superpowers/specs/2026-10-17-profile-badges-design.md`.

**Conventions:**
- Format only the files you touch.
- Run `git checkout pubspec.lock` if it changes.
- Commit after each task.

---

### Task 1: Strings

Add these to `AppText`, `AppTextEn`, `AppTextMl` and `AppStrings`, after `achievementPerfectDayCondition`. Also add them to `_members` in `test/core/strings/app_text_test.dart`.

| Key | English | Malayalam |
|---|---|---|
| `achievementNext(String title)` | `'Next: $title'` | `'അടുത്തത്: $title'` |
| `achievementStreakProgress(int current, int target)` | `'$current of $target days'` | `'$target-ൽ $current ദിവസം'` |
| `achievementsAllEarned` | `'Every badge earned'` | `'എല്ലാ ബാഡ്ജുകളും നേടി'` |
| `achievementLadderFirst` | `'First clear'` | `'ആദ്യ ജയം'` |
| `achievementLadderDays(int days)` | `'$days days'` | `'$days ദിവസം'` |
| `achievementsSpecial` | `'Special'` | `'പ്രത്യേകം'` |
| `achievementCurrentStreak(int days)` | `days == 1 ? 'Current streak: 1 day' : 'Current streak: $days days'` | `'ഇപ്പോഴത്തെ സ്ട്രീക്ക്: $days ദിവസം'` |

Run `flutter test test/core/strings/`. Expect PASS.

### Task 2: `nextAchievement`

`lib/domain/achievements/next_achievement.dart`:

```dart
import 'achievement.dart';

/// The badge to chase next: among the locked ones, the streak badge with
/// the most progress (current streak / target), else the first locked badge
/// in catalogue order (first clears come first). Null when all are earned.
Achievement? nextAchievement(
  Set<String> unlocked, {
  Map<String, int> currentStreakByGame = const {},
}) {
  Achievement? best;
  var bestScore = -1.0;
  for (final a in Achievements.all) {
    if (unlocked.contains(a.id)) continue;
    final streak = a.kind == AchievementKind.streak
        ? currentStreakByGame[a.gameId] ?? 0
        : 0;
    final score = streak > 0 ? streak / a.target : 0.0;
    if (score > bestScore) {
      best = a;
      bestScore = score;
    }
  }
  return best;
}
```

Tests in `test/domain/achievements/next_achievement_test.dart`:
- nothing earned: `first_clear_zip`
- all three first clears earned, Path Words streak 4: `streak_7_path_words`
- Zip streak 5 and Sudoku streak 20, with the 7s earned: Sudoku's 30 (20/30 beats 5/30)
- a streak at or above its target but not yet stored as earned still scores. It is excluded only via `unlocked`.
- everything earned: null

### Task 3: `AchievementMedal` and copy tests

- Create `lib/features/achievements/view/achievement_medal.dart` with `AchievementMedal({required Achievement achievement, required bool unlocked, double size = 48})`. It has the circle, the ember gradient and glow when unlocked, the paper fill and outline when locked, and the lock dot when locked. The icon is `size / 2`.
- Delete `achievement_badge_grid.dart`.
- Move the copy assertions from `achievement_badge_grid_test.dart` into `test/features/achievements/view/achievement_copy_test.dart`, and delete the grid test.

### Task 4: `AppLayout.scrollPadding`

```dart
/// [pagePadding], plus the bottom inset: the floating nav dock inside the
/// dashboard (its Scaffold has extendBody), the system bar elsewhere.
EdgeInsets scrollPadding(BuildContext context) => pagePadding.copyWith(
  bottom: pagePadding.bottom + MediaQuery.paddingOf(context).bottom,
);
```

Use it in:
- `ProfileScreen`'s scroll view
- Stats `_GameStatsPage`'s `ListView`
- `SettingsScreen` (replaces its inline sum)
- `BadgesScreen`

Test (`test/core/theme/app_layout_test.dart`): with `MediaQuery(padding: bottom 88)`, `scrollPadding(context).bottom == pagePadding.bottom + 88`.

### Task 5: `BadgesSummaryCard`

`lib/features/achievements/view/badges_summary_card.dart`, `BadgesSummaryCard({required StatsState state, required VoidCallback onOpen})`:

- **Header row:** title and count (the count only when ready), plus a chevron.
- **Progress:** `ClipRRect` + `LinearProgressIndicator(value: unlocked / total, minHeight: 6)`, ember on paper.
- **Medal row:** a `LayoutBuilder` fits `n = (width + 10) ~/ 50` medals of 40px with 10px gaps. If more are unlocked than fit, it shows `n - 1` medals and a "+k" circle.
- **Next row:** uses `nextAchievement(state.unlocked, currentStreakByGame: {for (e in state.stats.entries) e.key: e.value.currentStreak})`.
  - The subtitle is a streak's `achievementStreakProgress(min(current, target), target)` when it has a current streak above 0, otherwise its condition.
  - With nothing left to earn, the row is `achievementsAllEarned` with `Icons.verified_rounded`.
- **Shell:** `Semantics(button: true, label: '${achievementsTitle}, ${progress}', onTap: onOpen)` around `Material` + `InkWell(onTap: onOpen)`.

Tests:
- shows the count, medals and Next, with streak progress
- shows "+k" when the row overflows (16 unlocked at 320 wide)
- shows the all-earned line
- `onOpen` fires on tap

### Task 6: `BadgesScreen` and the route

- `lib/features/achievements/view/badges_screen.dart`: `BadgesScreen` provides `StatsCubit(loadHistory, refreshRemote: true)`. The body is a `ListView` with `scrollPadding`. It contains:
  - the summary (the count text plus the progress bar);
  - for each game, a `_GameLadder` card with the game title, four steps (`first_clear_X`, `streak_7_X`, `streak_30_X`, `streak_100_X`), connectors that are lit when both ends are earned, labels `achievementLadderFirst` and `achievementLadderDays(n)`, and a `achievementCurrentStreak` caption when the streak is above 0;
  - a `_SpecialCard` with rows for `perfect_day`, `zip_under_minute`, `hint_free_week` and `flawless_sudoku_10`.
- Each step and row has `Semantics(label: title, value: locked ? '$locked. $condition' : null)`.
- Loading shows a spinner. Failure shows `CenteredMessageBody(statsFailed, Retry)`. There is a `RefreshIndicator`.
- Route: `GoRoute(path: 'badges', name: 'profile_badges', builder: (_, _) => const BadgesScreen())` under `profile`.

Tests (`test/features/achievements/view/badges_screen_test.dart`):
- three ladders and four Special rows
- earned and locked semantics
- the current-streak caption
- failure, then Retry

### Task 7: Wire Profile

- `ProfileStatsSection` renders the stats row plus `BlocBuilder<StatsCubit, StatsState>` → `BadgesSummaryCard(state, onOpen: () => context.push('/profile/badges'))`.
- `ProfileScreen` uses `layout.scrollPadding(context)`.
- Update `profile_stats_section_test.dart`: there is no grid, the count stays, "First Zip" moves to the medal semantics and the Next line, and a tap opens `/profile/badges`.
- Check `malayalam_screens_test` Profile.

### Task 8: Verify

- Add a screenshot test, `test/features/achievements/view/badges_screenshots_test.dart`. It renders Profile (top and scrolled to the end) and Badges inside `Scaffold(extendBody, bottomNavigationBar: FloatingNavDock)`, and asserts that the last settings row's bottom is above the dock's top.
- Run `flutter analyze` (expect the base's 20 infos), then the full `flutter test`.
- Get an independent review and fix what it finds.
- Update the README Profile bullet.
- Push `feat/profile-badges` with an explicit branch name.
