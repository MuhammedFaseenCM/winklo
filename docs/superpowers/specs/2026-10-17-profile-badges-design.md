# Profile: a badges summary, a Badges screen, and clearance above the dock

Date: 2026-10-17 · Branch: `feat/profile-badges`, stacked on `feat/leaderboard-table`.

## Problem

**The badge grid crowds out Profile.** It shows all 16 badges, three to a row, and each one carries up to four lines of how-to-earn text. That is about 730px in English and more in Malayalam. Settings, Privacy and the account rows start two screens down.

**The dock covers the last row.** Profile's scroll view uses `layout.pagePadding`, which has a 20px bottom. The floating nav dock (about 88px) sits on top of the body (`Scaffold(extendBody: true)`). So "Delete account" ends under the dock. `/profile/stats` has the same problem.

## Decision (agreed in brainstorming)

Option A: Profile shows a compact Badges card, and the full collection moves to a new screen, `/profile/badges`.

## Profile: the Badges card

The card is about 190px tall. Tapping anywhere on it pushes `/profile/badges`. Its semantics read as a button labelled "Badges, 3 of 16".

From top to bottom:

1. **Header:** "Badges", then "3 of 16" and a chevron.
2. **Progress bar:** 6px tall, filled ember for `unlocked / 16`.
3. **Earned badges:** one row of 40px medals for the unlocked badges, in catalogue order, as many as fit. If some don't fit, a "+N" circle comes last. With nothing unlocked, this row is left out.
4. **Next badge:** a 32px locked medal, then "Next: {title}". Under the title:
   - for a streak badge, the progress, e.g. "4 of 7 days" (the game's current streak);
   - for any other badge, its condition.

   Once every badge is unlocked, this row reads "Every badge earned" with a check instead.

While the stats are loading, the card shows its header and an empty bar, with no row-count jump.

### Choosing the next badge

`nextAchievement(unlocked, currentStreakByGame)` is pure Dart in `domain/achievements/`.

- **Candidates:** the locked badges.
- **Streak badges:** score `currentStreak / target`, but only when the current streak is above 0.
- **Every other badge:** scores 0.
- **Pick:** the highest score wins, and ties go to catalogue order. If every score is 0, that means the first locked badge in catalogue order, which is a first clear before any streaks.
- **Nothing locked:** it returns null.

## `/profile/badges`: the Badges screen

The screen lives in the profile branch of the shell, so the dock stays visible under it.

- **App bar:** "Badges".
- **Summary:** "3 of 16" with a progress bar.
- **One card per game** (Zip, Path Words, Sudoku):
  - a ladder of four medals joined by a line: First clear, 7 days, 30 days, 100 days;
  - a lit segment of the line runs between consecutive earned steps;
  - a caption under the ladder gives the game's current streak, e.g. "Current streak: 4 days", or nothing when the streak is 0.
- **"Special" card:** four rows for Perfect day, Under a minute, Hint-free week and 10 flawless Sudokus. Each row has:
  - a 40px medal;
  - the title, with the condition under it;
  - a check when earned, or a lock when locked.
- **Medals:** the existing look. Earned medals are ember with a glow. Locked medals are dimmed and carry a lock.
- **Semantics:** each medal reads its title, plus "Locked. {condition}" when it is locked.
- **States:**
  - loading shows a spinner;
  - a failure shows the stats failure message with Retry;
  - pull to refresh reloads, with `refresh: true`;
  - the screen opens with `refreshRemote: true`, as Stats does.

## Clearance above the dock

`AppLayout.scrollPadding(BuildContext)` returns `pagePadding` plus `MediaQuery.paddingOf(context).bottom`. That bottom inset is the dock's height when the screen is inside the shell, and the system inset elsewhere. Settings already pads this way.

These screens use it:

- Profile
- Stats (each game page)
- Badges
- Settings, refactored to use the helper, with no change in behaviour

Result: the last row ends `pagePadding.bottom` (16–20px) above the dock.

## Code

**New, under `lib/features/achievements/`:**

- `view/achievement_medal.dart`: `AchievementMedal(achievement, unlocked, size)`, the circle, icon and lock. It is extracted from `AchievementBadge`.
- `view/badges_summary_card.dart`: Profile's card.
- `view/badges_screen.dart`: the route body.

**New in domain:** `domain/achievements/next_achievement.dart`.

**Changed:**

- `ProfileStatsSection` now shows the stats row plus `BadgesSummaryCard` instead of the grid.
- `app_router.dart` adds `profile/badges`.

**Removed:** `AchievementBadgeGrid` and `AchievementBadge`, which have no other users. Their copy tests move to a copy test.

## Strings

New entries in `AppText`, `AppTextEn` and `AppTextMl`:

| Key | English |
|---|---|
| `achievementNext` | "Next: {title}" |
| `achievementStreakProgress` | "{current} of {target} days" |
| `achievementsAllEarned` | "Every badge earned" |
| `achievementLadderFirst` | "First clear" |
| `achievementLadderDays` | "{n} days" |
| `achievementsSpecial` | "Special" |
| `achievementCurrentStreak` | "Current streak: {n} days" |

The new Malayalam strings are a first pass and go on the native-review list.

## Testing

- **Unit, `nextAchievement`:**
  - nothing earned → first Zip clear
  - a 4-day Path Words streak with first clears done → `streak_7_path_words`
  - two streaks → the one with more progress
  - all earned → null
- **Widgets:**
  - **summary card:** count, bar, medals, "+N", the Next line with streak progress, the all-earned line, and tapping opens `/profile/badges`
  - **Badges screen:** three ladders and the Special rows, lit versus locked, the current-streak caption, the failure and Retry state, and semantics
- **Profile screen:**
  - the last row ends above the dock at 360×640
  - Profile scrolls past the badges in under one screen of badge content
- **Screenshots** (`WINKLO_SCREENSHOTS=1`): Profile at the top and at the end, and the Badges screen, inside the real dock shell, in English. The Malayalam screens test still passes.

## Out of scope

- unlock dates or "recently earned" ordering (not stored)
- sharing badges
- new badges
- a redesign of the Stats screen beyond its bottom padding
