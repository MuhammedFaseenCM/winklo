# Results as a scoreboard

Date: 2026-10-21 · Branch: `feat/results-scoreboard` (from `origin/feat/leaderboard-podium` at `7f799be`, no version bump)

## Why

The user asked for a redesign of the daily Results screen, the screen after a Zip, Path Words or Sudoku clear that shows the time and the mini leaderboard. In the visual companion they picked two problems with today's screen:

- **C. The board rows look heavy and old.** Each row is a thick bordered card with gold, silver or bronze outlines and no rank number. They don't match the podium and table on the Leaderboard tab.
- **D. Too many stacked pieces, no clear story.** The logo, title, time card, countdown, a big "Leaderboard" heading, the rows and four buttons are all centred with the same weight, so nothing leads.

They didn't pick the other four, so these are out of scope: your own row being hidden, the oversized time card, the guest view, and more delight. The new layout fixes the hidden row and the time card anyway.

Choices made in the visual companion:

1. **Layout B, "Scoreboard":** a left-aligned time with a rank badge, a row of stat tiles, the board as a table card, and one action bar.
2. **Path Words B2, "Board | Words switch":** the table card gets a two-way switch, and Words shows the theme and the word chips.

Mockups: `.superpowers/brainstorm/58049-1792522148/content/final-design.html` (git-ignored). Screenshots of today's screen are in the same folder.

## Dependency

The branch is cut from `feat/leaderboard-podium`, because it reuses that branch's `LeaderboardTableRow`, `MedalCoin`, tinted avatars, `AppIcons` and `AppIcon`. That branch also changes four Results files (icon swaps), so branching from master would guarantee a conflict.

**Merge order:** first `feat/leaderboard-podium`, then this branch.

## Scope

**In scope:** daily Results for Zip, Path Words and Sudoku (`_CelebrateAndClaimResults` in `results_screen.dart`), both signed in and as a guest.

**Out of scope, unchanged:**
- `LocalResultsView` (archive, practice and bonus runs).
- The legacy fallback branch of `ResultsScreen.build` (non-daily runs without `local`).
- The review prompt (`_ReviewPromptHost`) keeps its behaviour.
- Analytics action names stay as they are: `play_next`, `share`, `leaderboard`, `home`.

## Layout (top to bottom)

All in `SafeArea`, 16dp side padding (was 24).

1. **Top bar** (34dp):
   - Left: a chip with the game's icon and title. The icons are `AppIcons.lightning` (Zip, ember), `AppIcons.path` (Path Words, sky) and `AppIcons.grid` (Sudoku, rose).
   - Right: the existing `NextPuzzleCountdown` with the clock icon, at `labelSmall`. It keeps today's period and day logic, including the "day has ended" wording.
   - `ZipMark` and the centred title are removed.
2. **Hero row:**
   - Left column:
     - `args.title` ("Puzzle cleared!") in `inkSoft`, 13sp, w600.
     - Under it, the time: `CountingPlayTime` plus `EmberBurst` and a light haptic on landing, as today. It is ember, w900, with the glow, at 56sp (48 when compact).
   - Right: the **rank badge** (see below).
   - The "time" caption under the number is removed. The kicker above it does that job.
3. **Stat tiles:** one to three equal-width tiles (see "Tiles"). The row is hidden when there are none.
4. **`NewAchievementsBanner`**, unchanged, when there are new badges. Its top padding becomes 0 and it gets a 10dp bottom gap.
5. **Board card**, `Expanded`, in the table card style (`leaderboardTableDecoration()`):
   - Path Words with a summary: a Board | Words switch at the top (see "Board | Words").
   - Signed in: the mini table (see "Mini table"). Guest: `ResultsBoardTease` filling the card.
6. **"Perfect day" line**, only when there's no next daily: `AppStrings.perfectDay` in teal, w800, centred, with an 8dp gap.
7. **Action bar** (46dp), with 8dp gaps. Signed in:
   - Next daily exists: `[share] [full board] [home]` as 46×46 outlined icon buttons with tooltips (`shareResult`, `resultsFullBoard`, `backHome`), then the primary `ZipPrimaryButton` "Play {game} next" with `AppIcons.play`, expanded.
   - No next daily: `[full board] [home]`, then the primary "Share" button (`shareResult`, `AppIcons.share`).
   - Share keeps the one-at-a-time guard (`_OneAtATimeButton` logic), whichever button holds it.
   - **Primary label fit:** "Play Path Words next" doesn't fit next to three icon buttons on a 360dp phone. If the full label overflows its width (measured with a `TextPainter` in a `LayoutBuilder`), the button shows the bare game title ("Path Words") with the play icon.
   - Guest: `[home]` (icon button, tooltip `backHome`), then the primary "Save 1:47 to today's board" (`saveTimeToBoard`, `AppIcons.trophy`). The "Back home" text button goes away.

Entrance motion stays light and keeps today's feel:
- Hero fades in at 0ms. The time counts up.
- Tiles pop in staggered from 520ms (60ms apart), using today's `badgeWrap` curve.
- The board card fades and slides up at 300ms, and the action bar fades in at 400ms.
- The rank badge fades and scales in when the board first has your entry.

## Rank badge

- A 76×76 rounded square (radius 20, 68×68 when compact), with an ember 12% fill and an ember 50% 1.5dp border.
- It shows "#14" in ember, w900, 24sp (22 compact), and "of 18 today" in `inkSoft`, 10sp. The caption is a new string, `resultsRankOfToday(total)`. Both lines sit in a `FittedBox(scaleDown)` for large text.
- **Data:** the board's `LeaderboardCubit`. The current entry is the one whose `uid == state.currentUid`. Rank is `entry.rank`, and total is `state.entries.length`.
- **Capped boards:** the daily query is capped at 50 rows (`leaderboard_repository_impl.dart`, `.limit(50)`). The literal moves to a shared constant, `leaderboardDailyLimit` in `domain/leaderboard_limits.dart` next to the other board limits, which the repository uses too. When `entries.length >= leaderboardDailyLimit`, the caption reads "of 50+ today" (`resultsRankOfToday(total, capped: true)`).
- **States:**
  - Loading: an empty badge outline, no text.
  - Ready with you on the board: the badge.
  - Ready but you're not on it (a refused submit, a pending write): the badge is hidden and the time takes the full width.
  - Guest: no badge.
- **Semantics:** "Rank 14 of 18 today" (new string `resultsRankSemantics(rank, total)`).
- **The cubit moves up:** `LeaderboardCubit` is created once at the top of the signed-in layout, above both the hero and the card, so the badge and the table share one stream. `MiniLeaderboardPanel` gets an optional external cubit, or reads it from context. The constructor that builds its own stays for other callers and tests.

## Tiles

A pure function in `lib/features/results/logic/result_tiles.dart` builds the tiles. It is plain Dart with no Flutter: it takes `ResultsArgs`-like facts and returns `List<ResultTile>`. The widget maps each tile to an icon, colour and strings.

```
sealed ResultTile
  StreakTile(current, longest?)      // fire, ember-amber; "6-day streak" / "Longest streak 11"
  PersonalBestTile()                 // star (fill), teal;  "New personal best"
  HintTimeTile(seconds)              // hint (lightbulb), soft white; "+20s" / "from hints"
  HintFreeTile()                     // noHints (brain), teal; "Hint-free"
  FlawlessTile()                     // flawless (seal-check), sky; "Flawless"
  BonusWordsTile(count)              // sparkle, sky; "+2 bonus words"
```

The rules, applied in order, keep the first three:
1. `StreakTile` when `currentStreak > 0`. The caption is `longestStreakLabel` only when longest is greater than current.
2. `PersonalBestTile` when `improved`.
3. One clean-run tile:
   - `HintTimeTile` when `hintPenaltySeconds > 0`.
   - Otherwise, for Sudoku, `FlawlessTile` when `usedHints == false && hadMistakes == false`.
   - Otherwise `HintFreeTile` when `usedHints == false`.
   - Otherwise none.
4. `BonusWordsTile` for Path Words when there is at least one bonus word.

`HintTimeTile` takes precedence over everything below it, so a time that includes hint seconds is always explained. The old "Includes +20s from hints" line under the time is removed, because this tile replaces it.

Tile style: radius 12, `inkSoft` 8% fill, 16% border, 8dp padding. The icon is an `AppIcon` at 18dp. The title is 12sp w800, up to 2 lines, centred. The caption is 10sp `inkSoft`, 1 line, ellipsized. Tiles in a row share the tallest tile's height (`IntrinsicHeight`).

## Mini table

- Rows are the podium branch's `LeaderboardTableRow` at its 52dp height, with `period: daily` and `gapSeconds` to #1 (hidden for #1, and when the gap is ≤ 0).
- **Medals:** with the new opt-in `showMedals`, `LeaderboardTableRow._rank` shows a `MedalCoin(rank, size: 22)` for ranks 1–3 instead of the number. Only the mini board sets it, so the tab's pinned row is unchanged.
- **Gap row:** a centred "···" (`leaderboardGapEllipsis`) row, 20dp, with the same divider.
- **Which rows (fit to height):** `sliceLeaderboardForMini` gains a `maxRows` mode. The card measures its height (`LayoutBuilder`) and passes `maxRows = floor((height − gapRow) / 52)`.
  - Always: everyone ranked 1–3 (ties included, so possibly more than three rows) and you.
  - Remaining slots go to your neighbours, alternating above and below and starting above (the people you're chasing).
  - If you're in the top 3, the slots go to ranks 4, 5, …
  - With room for everyone there is no gap row.
  - If even the top 3 plus you don't fit, the list scrolls (`ListView`), and your row is scrolled into view on first build.
  - Today's `above`/`below` parameters stay for existing callers.
- **Tap a row:** `showPlayerCardSheet` (`isYou` for your row), as on the tab.
- **States:**
  - Loading: today's centred spinner stays. The podium branch's `LeaderboardShimmer` draws a podium, and its row shimmer is private.
  - Failure: `CenteredMessageBody` with retry, as today.
  - Empty: `leaderboardEmpty`, as today.
- Results no longer uses the old `LeaderboardRow`. It stays, because `leaderboard_signed_out_mock.dart` still uses it.

## Board | Words (Path Words only)

- The switch shows when `args.pathWords != null`. It sits at the top of the board card: two segments with 8dp margins in a 10-radius track, the active segment in `mistDeep`.
  - Segment 1: `AppIcons.ranking` and "Board" (new string `resultsBoardTab`).
  - Segment 2: `AppIcons.textAa` and "Words · 5" (new string `resultsWordsTab(count)`).
- It opens on **Board**. The selection is view-local `StatefulWidget` state: it is ephemeral UI state, not app state.
- **Words** shows today's `PathWordsResultsPanel`: theme line, chips, "tap for meaning" and bonus count. It is centred in the card and scrolls if needed. Chip styling is unchanged, since it has room.
- Signed in: Board holds the mini table. Guest: Board holds the tease, and Words works the same.
- The panel and the theme line swap `Icons.*` for `AppIcons.*` if the podium branch didn't already.

## Small and short screens

- **Compact** (height < 700dp): hero 48sp, badge 68dp, tiles with 6dp padding and 16dp icons.
- **Too short** (landscape, split screen): the fixed layout needs about `topBar + hero + tiles + bar + 4 rows`. When the screen is shorter than that, the whole page scrolls in a `SingleChildScrollView`, with the card at a fixed 4-row height (`4 × 52 + gapRow`, plus the switch when shown). This replaces today's `_minHeaderHeight`/`_minBoardHeight` maths.

## Strings

New, in English and first-pass Malayalam. These go on the native-review list.
- `resultsRankOfToday(int total, {bool capped = false})`: "of $total today", or "of $total+ today" when capped
- `resultsRankSemantics(int rank, int total, {bool capped = false})`: "Rank $rank of $total today", with the same "+" rule
- `resultsHintTimeTile(int seconds)`: "+${seconds}s"
- `resultsFromHints`: "from hints"
- `resultsBoardTab`: "Board"
- `resultsWordsTab(int count)`: "Words · $count"

Reused: `newPersonalBest`, `streakLabel`, `longestStreakLabel`, `statsHintFree`, `leaderboardNoMistakesChip` ("Flawless"), `pathWordsBonusCount`, `perfectDay`, `playNextGame`, `shareResult`, `resultsFullBoard`, `backHome`, `saveTimeToBoard`, and the game titles. `resultsTimeLabel` and `resultsHintPenalty` stay, because `LocalResultsView` uses them.

## Files

- `lib/features/results/results_screen.dart`:
  - `_CelebrateAndClaimResults` is rebuilt as the layout above.
  - `_ResultsCelebrationCard` is replaced by `ResultsHero`.
  - The legacy fallback branch keeps a private copy of the old card, or uses `ResultsHero` if that is simpler. Its look may change slightly, since it's legacy and rarely shown.
- New `lib/features/results/view/results_top_bar.dart`: the game chip and countdown. `_NextPuzzleLine` moves here.
- New `lib/features/results/view/results_hero.dart`: the time and rank badge.
- New `lib/features/results/view/result_tiles_row.dart`: maps `ResultTile` to tiles.
- New `lib/features/results/logic/result_tiles.dart`: the pure tile rules.
- New `lib/features/results/view/results_board_card.dart`: the card, the switch, and the board or tease and words.
- `lib/features/results/view/mini_leaderboard_panel.dart`:
  - Becomes the table body: no title row, no footer.
  - Uses `LeaderboardTableRow`, takes the cubit from context, and fits rows to height.
  - The "See full leaderboard" footer default goes away. Results is its only caller.
- `lib/features/results/view/results_actions.dart`: becomes the action bar described above, with tooltips, the primary-label fit, and the perfect-day variant.
- `lib/features/leaderboard/logic/mini_leaderboard_slice.dart`: gains the `maxRows` mode.
- `lib/features/leaderboard/view/widgets/leaderboard_table.dart`: medal coins for ranks 1–3 in `_rank`.
- `lib/core/strings/app_text*.dart` and `app_strings.dart`: the new strings.

## Testing

- **Unit:**
  - `result_tiles_test.dart` covers each rule, the order, and the cap at 3, including hint time taking precedence and Sudoku flawless versus hint-free.
  - `mini_leaderboard_slice_test.dart` covers `maxRows`: you in the top 3, you last, you in the middle, room for everyone, and too little room.
- **Widget:**
  - `results_screen_test.dart` and `results_actions_test.dart` move from button texts to tooltips for share, full board and home.
  - New checks: the rank badge "#14", the badge hidden when you're off the board, tiles for the PB/streak/hints case, the Words tab showing the chips and bonus count after a tap, the Perfect day primary share, and the guest save button and home icon.
  - The existing "typical phone shows the whole celebration…" and "scrolls the whole page" tests are updated to the new layout.
  - The review-prompt and achievements tests stay green unchanged.
- **Screenshots:** `test/features/results/results_screenshots_test.dart`, with `WINKLO_SCREENSHOTS=1`. It covers Zip signed in at 390×844 and 360×640, Path Words on the Board and Words tabs, Sudoku perfect day, and a guest. Every case asserts no overflow.
- **Full suite:** the 11 failures already on master and the podium branch (profile_screen_test, leagues dialog text, app_layout_test, leaderboard_repository_impl_test) may stay. No new failures.

## Known limits

- A player ranked below the 50-row cap isn't in the stream, so the badge is hidden and the table shows no "you" row. That is today's behaviour too.
- Tiles show no "beat 1:53" style detail: `ResultsArgs` carries `improved` but not the previous best, and adding that plumbing to three blocs isn't worth it for this redesign.
