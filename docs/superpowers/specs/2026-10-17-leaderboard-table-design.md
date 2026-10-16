# Leaderboard tab: two pickers and a table

Date: 2026-10-17 · Branch: `feat/leaderboard-table` (from `feat/roadmap-batch`)

## Problem

The Leaderboard tab stacks four control rows above the board: game tabs,
period tabs (Daily / This week / All-time), league chips (Everyone + each
league), and the 14-day strip. On a 390×800 phone they take about 282px.
With the 88px nav dock, about 5 card rows (64px + 8px gap) fit. The league
row grows sideways as players join more leagues.

## Decisions (agreed in brainstorming)

- **Fix both** the controls and the rows.
- **Layout A, "two pickers"**: game tabs stay; everything else folds into
  two pills on one row.
- **Weekly stays "This week" only.** No past weeks.
- **Board sheet uses a calendar grid**, Monday first, because weekly boards
  are ISO weeks.
- **League sheet** replaces the league chips *and* the 👥 header button.
- **Clean-run chips become icons** in the row. The player card still spells
  them out.

## Screen, top to bottom

1. **Header.** The title, plus a back button when the screen is pushed. The
   `leaderboard_manage_leagues` button is removed.
2. **Game tabs.** The existing pill track, 36px tall (was 48px).
3. **Filter row** (34px):
   - **Board pill** (`leaderboard_board_pill`). Label: "Today",
     "Yesterday", a short date ("14 Oct"), "This week", or "All-time".
     Tapping opens the board sheet.
   - **Scope pill** (`leaderboard_scope_pill`). Shown only when signed in.
     Label: "Everyone" or the league name (ellipsis at 160px). Tapping
     opens the scope sheet.
4. **Table card.** One rounded card holding:
   - a 30px column header that stays put while the rows scroll
   - 48px rows separated by hairlines
5. **Unchanged:** the pinned "You" row (now a table row), the sign-in
   button for signed-out players, the empty / failed / loading states, and
   the slide animation when the board changes.

Target: on a 390×800 phone, at least 9 rows are visible above the dock.

## Board sheet: "Which board?"

A modal bottom sheet with:

- **This week** row, subtitled "Days cleared, then total time".
- **All-time** row, subtitled "Best time ever". Hidden when the
  `showAllTimeLeaderboard` Remote Config flag is off.
- Label "A single day · last 14 days", then a 7-column calendar.
  - Weekday initials come from `MaterialLocalizations.narrowWeekdays`,
    reordered Monday first.
  - Rows run from the Monday of the oldest day's week to the Sunday of
    today's week.
  - Cells outside the 14 days (before the window, or after today) are
    dimmed and can't be tapped.
  - The selected board is filled ember; today has an ember outline.
  - Each cell has a semantics label with the full date.

Picking anything closes the sheet and returns the choice. The screen then
calls `LeaderboardCubit.selectBoard`.

## Scope sheet: "Whose scores?"

A modal bottom sheet with:

- **Everyone**, subtitled "Top 50".
- **One row per league**, with a lettered tile and "{n} players".
- **The selected row** is highlighted.
- **One button at the bottom.** It reads "Manage leagues" when the player
  has leagues, otherwise "Create or join a league". Either way it pushes
  `/leagues`.

## Table rows

`LeaderboardTableRow`. Columns:

| Board | Columns after rank · avatar · player |
|---|---|
| Daily (any day) | Time |
| This week | Days (teal) · Total |
| All-time | Best |

- **Rank.** Ranks 1–3 keep the medal art at 24px; other ranks are plain
  numbers.
- **Avatar.** `UserAvatar` at radius 14.
- **Name.** One line with an ellipsis.
- **Name icons** (daily boards only), each with a semantics label and
  tooltip:
  - no hint: `Icons.lightbulb_outline` in teal
  - no mistakes (Sudoku): `Icons.verified_outlined` in blue
  - streak ≥ 2: flame and number in amber
- **Numbers.** Tabular figures, right-aligned. Time uses
  `AppStrings.formatPlayTime`.
- **"You" row.** Ember tint and a 3px ember bar on the left; the time is
  in ember.
- **Tap.** Opens the player card, as before.

`LeaderboardRow`, the card row, stays as it is for the Results mini board
and the signed-out tease. Neither is in scope.

## State

`LeaderboardCubit.selectBoard(LeaderboardPeriod period, {String? dayId})`
sets the period and day in one emit with one resubscribe, which avoids the
double load that `selectPeriod` then `selectDay` would cause.

- For daily, `dayId` follows the same rules as `selectDay`: today maps to
  null, and days outside the window are ignored.
- For weekly and all-time, it clears `dayId`, so the next daily pick
  starts clean.
- If nothing changed, it does nothing.

`selectPeriod`, `selectDay` and `selectLeague` stay. Route sync and tests
use them.

## Code layout

New, under `lib/features/leaderboard/`:

- `logic/board_calendar.dart`: pure Dart. It builds the calendar weeks
  (Monday-first rows of cells: `dayId` or null, and whether the cell is in
  the window) from `recentDayIds`. It also has `leaderboardDayLabel`,
  moved here from the day strip.
- `view/widgets/leaderboard_filter_row.dart`: the two pills.
- `view/widgets/leaderboard_board_sheet.dart`: `showLeaderboardBoardSheet`,
  which returns `LeaderboardBoardChoice?` (period + dayId).
- `view/widgets/leaderboard_scope_sheet.dart`: `showLeaderboardScopeSheet`,
  which returns `LeaderboardScopeChoice?` (a league id, or null for
  Everyone).
- `view/widgets/leaderboard_table.dart`: `LeaderboardTableHeader` and
  `LeaderboardTableRow`.
- `view/widgets/leaderboard_game_tabs.dart`: the segment bar and pill
  track, moved out of the 1,200-line screen file.

Removed: `leaderboard_scope_bar.dart` and `leaderboard_day_strip.dart`.

`leaderboard_shimmer.dart` now draws table-shaped rows inside the same card.

## Strings

New entries in `AppText`, `AppTextEn` and `AppTextMl`, exposed through
`AppStrings`:

- the two sheet titles
- the This week / All-time subtitles
- the calendar label
- the column headers: Player, Time, Days, Total, Best
- `{n} players` and "Top 50"
- Manage leagues and Create or join a league
- semantics labels for the pills, the calendar cells and the icons

The Malayalam copy is first-pass and goes on the native-review list,
alongside the existing Malayalam strings.

## Accessibility

- Each pill is a button whose semantics read "{what}: {current}" (e.g.
  "Board: Today").
- Tap targets are at least 40px: calendar cells are 40px and rows are 48px.
- Name icons have labels.
- Dimmed calendar cells are excluded from semantics.

## Testing

- **Cubit (`bloc_test`).** `selectBoard`:
  - daily with a past day → one load with that day
  - weekly from a past day → one load, `dayId` cleared
  - same board → no emit
  - a day outside the window is ignored
- **Logic.** `board_calendar`:
  - Saturday 17 Oct 2026 → 3 week rows, Sun 4 Oct to Sat 17 Oct inside the
    window, Mon 28 Sep and Sun 18 Oct outside
  - a Monday today → 3 rows; a Sunday today → exactly 2 full rows
  - a year boundary
- **Widgets.**
  - board pill → the sheet picks yesterday, This week and All-time, and
    each loads the right board (period and dayId)
  - the pill label follows the board
  - All-time is hidden when the flag is off
  - the scope pill picks a league, and member UIDs are passed
  - Manage leagues pushes `/leagues`
  - no leagues → the "Create or join" button
  - signed out → no scope pill
  - the weekly table shows the Days and Total columns
  - the daily row shows the icons and the you-row
  - 360×640 fits with no overflow
  - 390×800 shows at least 9 rows
- **Updated.** The area-C and screen tests that used the strip, chip and
  manage-leagues keys now go through the pills. The tests for the pinned
  row, signed-out view, empty, failed and shimmer states keep their intent.

## Out of scope

- past weeks
- the Results mini board and tease
- the admin console leaderboard
- backend and Firestore changes
- tablet-specific layouts (the table card is capped at 640px wide and
  centred)
