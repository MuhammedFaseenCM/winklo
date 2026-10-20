# Leaderboard podium and Phosphor icons

Date: 2026-10-20 · Branch: `feat/leaderboard-podium` (from `origin/master` at 1.1.1+20)

## Why

The user said the Leaderboard tab "is not looking good". In the review they picked two problems:

- **B. Flat and spreadsheet-like.** Every row has the same grey letter circle, name and time, and nothing says "race".
- **D. Cryptic icons.** The struck-through bulb (no hints) and the bare flame plus number (streak) are hard to read.

They didn't pick the other four: the top-3 outlines, the chrome above the rows, the "Your Rank" tag, and the missing field context. Those stay as they are, apart from what the redesign itself changes.

Choices made in the visual companion:

1. **Direction: Podium.** The top 3 stand on a podium. Everyone below shows their gap to #1.
2. **Badges: icons plus a key.** Rows stay on one line with icons beside the name, and a small key explains the icons.
3. **Icon set: Phosphor duotone.** The user wants standard icons, not emoji.
4. **Scope: the whole app moves to Phosphor**, not just the leaderboard.

Mockups: `.superpowers/brainstorm/37245-1792507142/content/final-design.html` (git-ignored).

## Part 1: Phosphor across the app

### Package and icon map

- Add `phosphor_flutter: ^2.1.0`. It ships Phosphor 2.1, including duotone, and its `IconData` consts can be tree-shaken.
- New `lib/core/theme/app_icons.dart` holds `abstract final class AppIcons`. It is the only file that imports Phosphor's icon classes. It has one `static const IconData` per meaning, for example `AppIcons.trophy`, `AppIcons.streak`, `AppIcons.noHints`, `AppIcons.back` and `AppIcons.chevronRight`. Every other file uses `AppIcons.*` and never uses `Icons.*` or `PhosphorIcons*` directly.
- **Style.** Duotone by default. A few `*Fill` entries cover selected states: the nav dock's active tab, and filled versus empty stars. Phosphor's regular style is used only where a thin outline reads better at 12–14px, such as the caret in the picker pills.

### `AppIcon` widget

New `lib/core/widgets/app_icon.dart` holds `AppIcon(IconData icon, {size, color, semanticLabel})`.

- For a `PhosphorDuotoneIconData`, it stacks the secondary layer, then the primary glyph:
  - The secondary layer is the resolved color (explicit, or else `IconTheme`) at 22% opacity, applied as color alpha. It uses no `Opacity` widget, so no `saveLayer` is needed. It sits inside `ExcludeSemantics`, so screen readers announce the icon once.
  - The primary glyph is a plain `Icon(icon, …)`.
- Any other `IconData` (fill or regular) renders as a plain `Icon`.
- We don't use Phosphor's own `PhosphorIcon`. It wraps the second layer in `Opacity` and passes `semanticLabel` and `key` to both layers.
- Tests can still use `find.byIcon(AppIcons.x)`, because the primary layer is an `Icon` whose `icon` is the duotone `IconData`.

### Migration

- All 192 `Icons.*` uses in `lib/` (96 distinct names, 65 files) and 20 in `test/` (11 files) move to `AppIcons.*`.
- `Icon(` call sites become `AppIcon(`.
- Shared widgets that take an `IconData` and build `Icon(icon)` (`ZipPrimaryButton`, `LeaderboardFilterRow`, sheet tiles and others) build `AppIcon(icon)` instead.
- Default Material icons: `ThemeData.actionIconTheme` sets `backButtonIconBuilder` and `closeButtonIconBuilder` to the Phosphor back and close glyphs, so `BackButton` and `CloseButton` match too.
- The app launcher icon and image assets are out of scope.
- **Mapping.** Material names map to Phosphor glyphs by meaning, not by name:

  | Material | Phosphor |
  |---|---|
  | `emoji_events` | `trophy` |
  | `local_fire_department` | `fire` |
  | `lightbulb` | `lightbulb` |
  | `bolt` | `lightning` |
  | `route` | `path` |
  | `grid_on` | `gridFour` |
  | `public` | `globeHemisphereWest` |
  | `group` | `usersThree` |
  | `today` | `calendarDot` |
  | `date_range` | `calendarDots` |
  | `military_tech` | `medal` |
  | `verified` | `sealCheck` |
  | `ac_unit` | `snowflake` |
  | `my_location` | `crosshair` |
  | `chevron_*` / `expand_more` | `caret*` |

  Every other icon gets the nearest equivalent. The full list lives in `app_icons.dart`, grouped by area.

### Test harness

- `test/helpers/screenshot.dart` loads the Phosphor duotone, fill and regular TTFs from the package, as it already does for Material Icons. Screenshots then show real glyphs.

## Part 2: Leaderboard redesign

### Layout of the board

The list changes from `ListView.builder` to a `CustomScrollView`, and everything scrolls together:

1. **`LeaderboardPodium`** shows the first `min(3, n)` entries in 2-1-3 order. With 1 entry only the centre step shows; with 2 entries, steps 1 and 2.
2. **`LeaderboardBadgeKey`**, on the daily board only, when at least one listed entry earns a badge. It is one centred line listing only the badge kinds present: "Hint-free" (brain, teal), "Flawless" (seal-check, blue, Sudoku only) and "Day streak" (fire, amber).
3. **The table card** holds entries 4 and up (index 3+). It keeps the dark rounded card, built with `DecoratedSliver`, and a `SliverFixedExtentList` with `itemExtent: leaderboardTableRowHeight`. The column header shows only on the weekly board ("# · Player · Days · Total"). Daily and all-time have a single time column, so they need no header.
4. Bottom padding stays as today: room for the pinned row, plus the sign-in button for guests.

If the board has 3 entries or fewer, there is no table card, just the podium (and the key).

### Podium

- Each slot shows:
  - the avatar: 54dp for #1, 44dp for #2 and #3, with a 2–2.5dp ring in gold, silver or bronze; #1 also gets a soft gold glow
  - the name (1 line, ellipsized)
  - daily badges as small icons after the name, without the streak number on #2 and #3 if space is short
  - the time, in gold for #1 and in the normal text colour for the others
  - on the weekly board, the days cleared ("7 days") under the time
  - a step block with a drawn **`MedalCoin`**
- Step heights are 60, 44 and 32 at 1.0 scale, using `AppLayout.space`.
- #1 gets a Phosphor `crownSimple` (duotone, gold) above the avatar.
- A soft gold radial wash sits behind the podium.
- **You on the podium:** your name is ember with the "You" pill under it. The podium slot carries `_userRowKey`, so visibility checks still work.
- **Tap** on a slot opens `showPlayerCardSheet`, as rows do.
- **Semantics** per slot: "Rank N, name, time", with badges read by label.

### MedalCoin

- `MedalCoin(rank, size)` is drawn in Flutter: a radial gradient (gold, silver, bronze), a thin darker rim, and the rank number in dark ink.
- It replaces the network medal PNGs on this screen, so medals show offline and in tests. The Results mini board (`LeaderboardRow`) keeps its PNG medals.

### Rows (rank 4 and up)

- Rank number in muted text; the grey rank circle is removed.
- Avatar: photos and preset avatars are unchanged. A plain-initials avatar is tinted with one of 7 app hues, chosen by a stable hash of the uid: ember, sky, teal, rose, violet, amber, lime. The circle is the hue at 18% alpha and the initial is in the hue. This uses a new optional `UserAvatar.tintSeed`. Other screens don't pass it, so they don't change.
- Name, then badge icons. These are `AppIcon`s at 15dp: brain for hint-free, seal-check for flawless, and fire plus number for a streak of 2 or more.
- Time column:
  - Daily and all-time: the time, with **`+m:ss` gap to #1** under it in muted 10sp (`entry.timeSeconds - entries.first.timeSeconds`). The gap is hidden when it is 0 or less.
  - Weekly: Days, then Total, with no gap, because days cleared rank first.
- Row height goes from 56 to 52. The fixed-width time and days cells keep the `_FitCell` scale-down behaviour for large text.
- The You row keeps its ember wash, left bar and "You" pill.
- The old top-3 bordered styling (`_podiumWash`, `_podiumAccent`, and the network medal in `_rank`) is removed. Ranks 1–3 never render as rows on this screen any more.

### Pinned "You" row

- Unchanged, except for one sub-line on daily and all-time boards: **"0:05 behind #13"**. It compares you with the entry directly above you. That entry is always loaded, because the pin only exists when your entry is in the list.
- The sub-line is hidden when the gap is 0 or less, and on the weekly board.
- The "Your Rank" tag's icon becomes `AppIcons.locate` (Phosphor `crosshair`).

### Scroll maths

`_scrollToUser` and the `_isUserReached` fallback currently assume `top = index × rowHeight`. They become:

- `index < 3` means you're on the podium, so offset 0.
- Otherwise `top = headExtent + (index − 3) × rowHeight`. `headExtent` is measured from a `GlobalKey` on the podium, key and header block. Its render box stays laid out while the board scrolls, because a `SliverToBoxAdapter`'s child always lays out.
- `inInitialList` (`userIndex < 6`) stays as the heuristic for whether a pin can ever appear.

### Shimmer

`LeaderboardShimmer` mirrors the new layout: a three-step podium skeleton (circles and bars), then 52dp row skeletons inside the card.

### Strings (en, plus first-pass ml for native review)

- `leaderboardKeyStreak`: "Day streak", ml "ദിവസ സ്ട്രീക്ക്".
- `leaderboardBehind(String gap, int rank)`: "$gap behind #$rank", ml "#$rank-നേക്കാൾ $gap പിന്നിൽ".
- `leaderboardPodiumSemantics(int rank, String name, String time)`: "Rank $rank, $name, $time", ml "റാങ്ക് $rank, $name, $time".
- `leaderboardDaysShort(int days)`: "1 day" / "$days days", ml "$days ദിവസം".
- Reused: `leaderboardNoHintChip` ("Hint-free"), `leaderboardNoMistakesChip` ("Flawless"), `youLabel`.

## Out of scope

- Data, Firestore, the Worker, and the 50-row query limit. The "N played" count from the first mockup was dropped because the 50-row cap would make it wrong.
- The tabs, the picker sheets, and the picker row's layout. Only their icons change.
- Past weeks and new boards.

## Testing

- **Unit:**
  - `AppIcon`: two layers for duotone, one for fill or regular; the secondary layer is excluded from semantics; the colour comes from `IconTheme`.
  - Avatar tint: stable for a uid, and within the palette.
  - Gap and "behind" formatting.
- **Widget:**
  - Podium with 1, 2, 3 and more entries.
  - You on the podium versus in the rows.
  - The key shows only the badge kinds present, and none on weekly.
  - Weekly podium shows days; rows show Days and Total with no gap.
  - Rows show the gap on daily and all-time.
  - The pinned row shows "behind #N".
  - Tap opens the player card.
  - Scroll-to-you with the podium offset.
  - Existing leaderboard tests updated for the new structure.
- **App-wide:** the full `flutter test` suite stays green after the icon migration. `flutter analyze` is clean.
- **Screenshots:** `WINKLO_SCREENSHOTS=1 flutter test test/features/leaderboard/view/leaderboard_screenshots_test.dart` covers daily, weekly, league, sheets, 360×640 and 390×800, plus a Profile and Home spot-check for the icon swap.

## Rollout

- Ships as a normal app release. No backend or rules changes, and no version bump on this branch. The user picks the version at merge, since `fix/leaderboard-skips` already claims 1.1.2+21.
- The new Malayalam strings go on the native-review list.
