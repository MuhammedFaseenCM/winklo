# Levels Backdrops and Header Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Levels world theme gets its own background drawn in code. Locked worlds show a faded version of their own pattern. Switching games animates. The header chips, world labels and in-game goal chips get fixed.

**Architecture:**
- One `LevelThemePalette` per theme feeds the backdrop, path and node painters.
- Each theme gets its own small backdrop painter function in `levels/view/widgets/backdrops/`.
- The header gets a sliding pill, and the map switches with a slide-and-fade `AnimatedSwitcher` keyed on the game.

**Tech Stack:** Flutter (CustomPainter, implicit animations), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-23-levels-backdrops-design.md`

## Global Constraints

- **Branch** `feat/levels-backdrops`, in worktree `/Users/muhammedfaseencm/winklo/.worktrees/run-master`. Never commit to `master`.
- **Ink and Metro backdrops, paths and nodes render exactly as today.** The existing `test/features/levels/view/map_painters_test.dart` assertions on ink and metro stay unedited.
- **Themes covered:**
  - Path Words: `animals`, `food`, `sports`, `nature`, `home`, `body`.
  - Zip: `embroidery`, `neon`, `sparkler`.
  - Any other theme keeps the plain `ZipColors.ink` fill and today's locked look.
- **Contrast:** for each theme, the reached-path colour and the node fill must reach at least 3:1 against the palette's base colour (WCAG relative luminance).
- **Painting is deterministic.** Use no `Random()` without a fixed seed derived from the band rect or the world order. A painter repaints only for a new layout; keep `shouldRepaint` as it is.
- **The switch animation** runs about 300 ms with `Curves.easeOutCubic`. When `MediaQuery.disableAnimationsOf(context)` is true it doesn't animate.
- **User-facing copy** goes through `AppStrings`, in both en and ml.
  - The game chip shows `AppStrings.pathWordsTitle` ("Path Words").
  - `pathWordsTab` stays as it is, because the leaderboard tabs use it.
- **Analyze and tests:**
  - `flutter analyze` must stay at the baseline of 20 info issues.
  - The full `flutter test` must stay green.
  - Run `dart format` only on the files you changed.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Readability on every new backdrop.** The path, the dots on locked segments, the node numbers and the lock icons must stay readable, and so must a `_WorldLabel` sitting over the busiest part of the motif. *Task 1 (palette contrast test), Task 2.*
2. **Switching quickly back and forth** (Zip, Path Words, Zip within 300 ms). No duplicate cubits, no exception, and the final map matches the selected chip. *Task 4.*
3. **Reduce-motion and large text (2.0×).** The chips wrap without overflow and the switch happens with no animation. *Task 4.*
4. **A Path Words world whose levels vary in size.** The locked label shows "3 × 3 – 6 × 6". A Zip world, where every level has the same size, still shows "5 × 5". *Task 5.*
5. **The `?open=` deep link** still opens the right game and sheet while the switch animation is playing. *Task 4.*

---

### Task 1: Theme palettes; paths and nodes use them

**Files:**
- Create: `lib/features/levels/view/widgets/level_theme_palette.dart`
- Modify: `lib/features/levels/view/widgets/level_path_painter.dart:36-72`, `lib/features/levels/view/widgets/level_node.dart:40-46` and `_NodePainter`
- Test: `test/features/levels/view/level_theme_palette_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class LevelThemePalette {
    const LevelThemePalette({required this.base, this.baseEnd, required this.motif,
      required this.path, required this.pathWidth, required this.dots,
      required this.nodeFill, required this.number, required this.lockedNumber});
    final Color base;        // backdrop ground (top of a gradient when baseEnd is set)
    final Color? baseEnd;    // bottom of the gradient, or null for flat
    final Color motif;       // motif line/shape colour (with alpha)
    final Color path;        // reached path stroke
    final double pathWidth;
    final Color dots;        // locked path dots
    final Color nodeFill;    // open node fill
    final Color number;      // open node number
    final Color lockedNumber;// locked node lock icon / number
    static LevelThemePalette of(String theme);   // ink/metro return today's exact values; unknown → plain
    static const themes = ['ink','metro','embroidery','neon','sparkler','animals','food','sports','nature','home','body'];
  }
  ```

- [ ] **Step 1: Write failing tests.**
  - `ink and metro keep today's colours`: assert the exact current values from `level_path_painter.dart` and `level_node.dart`.
    - Ink: `path == InkPalette.rice`, width 8, `dots == InkPalette.pencil`.
    - Metro: `path == ZipColors.sky`, width 7.
  - `an unknown theme is the plain look`: `of('x').base == ZipColors.ink` and `path == ZipColors.onInk.withValues(alpha: 0.6)`.
  - `every theme's path and node reach 3:1 against its base`: for each of `themes`, `contrast(path, base) >= 3` and `contrast(nodeFill, base) >= 3`. Use the WCAG luminance helper inside the test.
- [ ] **Step 2:** Run `flutter test test/features/levels/view/level_theme_palette_test.dart`. Expected: FAIL, because the file is missing.
- [ ] **Step 3: Implement the palette** with colours that match the spec table. Then switch `LevelPathPainter` and `LevelNode`/`_NodePainter` to `LevelThemePalette.of(theme)`, keeping ink and metro identical.
- [ ] **Step 4:** Run the new test plus `test/features/levels`. Expected: PASS, with `map_painters_test.dart` unedited.
- [ ] **Step 5:** Commit with `feat(levels): a colour palette per world theme for paths and nodes`.

### Task 2: A backdrop for every theme

**Files:**
- Create: `lib/features/levels/view/widgets/backdrops/backdrops.dart`, one `paintXBackdrop(Canvas, Rect, LevelThemePalette)` function per new theme (9 functions). Put them in one file, or split into part files if it gets past about 400 lines.
- Modify: `lib/features/levels/view/widgets/world_backdrop_painter.dart` (the switch dispatches to the new functions; ink and metro stay)
- Test: `test/features/levels/view/map_painters_test.dart` (add cases; leave existing ones unedited)

**Interfaces:**
- Consumes: Task 1's `LevelThemePalette`.
- Produces: `void paintThemeBackdrop(Canvas canvas, Rect rect, String theme, {required bool open})`. `WorldBackdropPainter` calls it for every band.

- [ ] **Step 1: Write failing tests.** Use the existing harness in `map_painters_test.dart`, which builds bands for given themes and pumps the painters.
  - `every theme's open band paints without errors at 360 and 1080 px wide`: one band per theme in `LevelThemePalette.themes`. Pump it and expect no exception.
  - `a new theme's open band is not the plain fill`: for each of the 9 new themes, check a pixel or a recorded draw call. Following the existing ink test's approach, read the base colour at the band's centre from `toImage` and assert it isn't `ZipColors.ink`.
  - `painting is deterministic`: paint the same band twice to images and compare the bytes.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3: Implement the motifs from the spec table.**
  - animals: a gradient plus about 14 faint paw prints, each 4 toe ovals and a pad, rotated along a seeded diagonal.
  - food: gingham, with translucent vertical and horizontal stripes of about 28 px.
  - sports: pitch green, with a white centre line, centre circle and two boxes.
  - nature: teal, with 5–7 offset wavy contour paths and leaf dots.
  - home: a diamond lattice, with 3 rows of plank strokes at the band's bottom.
  - body: rose rings of 3 sizes.
  - embroidery: a cross-stitch "x" grid on navy linen.
  - neon: 3 tube strokes with a blur `MaskFilter` glow.
  - sparkler: 4-point star sparks.

  Keep the motif alpha low (about 0.12–0.30), so nodes and labels stay readable.
- [ ] **Step 4:** Run `flutter test test/features/levels`. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(levels): drawn backdrops for every world theme`.

### Task 3: Locked worlds preview their own motif

**Files:**
- Modify: `lib/features/levels/view/widgets/world_backdrop_painter.dart` (`_unprinted`), `backdrops/backdrops.dart`
- Test: `test/features/levels/view/map_painters_test.dart`

**Interfaces:**
- Consumes: Task 2's `paintThemeBackdrop(..., open: false)`.

- [ ] **Step 1: Write failing tests.**
  - `a locked themed world previews its motif`: a locked `food` band paints on `ZipColors.ink` with motif strokes, not the metro dashes. Assert this through the image: the band centre is still ink, and the band isn't identical to the locked image of an `ink`-theme band.
  - `a locked ink or metro world keeps today's unprinted outlines`: the image is byte-identical to the current `_unprinted` output, captured before the change.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** For a theme with a motif, a locked world draws that motif's strokes dashed at alpha about 0.18 on `ZipColors.ink`. Themes without a motif keep `_metroLines` dashes.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(levels): locked worlds preview their own backdrop`.

### Task 4: Header — the Sudoku chip, the "Path Words" label, the sliding pill, the map switch animation

**Files:**
- Modify: `lib/features/levels/view/levels_screen.dart` (the `_Header`, `_GameChip` and `_Chip` area at about lines 300-500, and the build where the keyed `BlocProvider` lives)
- Modify: `lib/core/strings/app_strings.dart`, `app_text.dart`, `app_text_en.dart`, `app_text_ml.dart`
- Test: `test/features/levels/view/levels_screen_test.dart`

**Interfaces:**
- Produces: `AppStrings.levelsSudokuSoon`, the snackbar text "Sudoku levels are coming soon" (en) with an ml equivalent.

- [ ] **Step 1: Write failing tests.**
  - `the game chips read Zip and Path Words`: find `AppStrings.pathWordsTitle`.
  - `the Sudoku chip lines up with the game chips`: `tester.getCenter` of its text has the same dy as the Zip chip text, within 0.5, and the same height.
  - `the Sudoku chip is a disabled button that says it's coming soon`:
    - its semantics have `button: true` and `enabled: false`;
    - tapping it shows a SnackBar with `AppStrings.levelsSudokuSoon`;
    - the game stays the same.
  - `switching slides the map`: tap Path Words. After `pump(150ms)`, both maps are in the tree, and a `SlideTransition` is present. After `pumpAndSettle`, only the Path Words map remains.
  - `with reduce motion the switch is instant`: wrap in `MediaQuery(data: ...copyWith(disableAnimations: true))`. After a single `pump()`, only the new map is in the tree.
  - `rapid switching settles on the last chip`: tap Path Words, Zip, Path Words within 100 ms, then `pumpAndSettle`. Only the Path Words map is present, with no exceptions.
  - `the chips don't overflow at 2.0× text`: set `textScaler` to 2.0 and expect no overflow error.
- [ ] **Step 2:** Run the tests. Expected: FAIL.
- [ ] **Step 3: Implement.**
  - **Sudoku chip.** Give it the same 48 px min-height wrapper as the game chips, dimmed (opacity 0.55), with `AppIcons.lock` at size 12 and "Sudoku · Soon". Wrap it in `Semantics(button: true, enabled: false)`, and on tap show the snackbar.
  - **Pill.** Animate the selected chip with `AnimatedContainer` (colour, 300 ms), or use one moving pill. Either is acceptable.
  - **Map switch.** Use an `AnimatedSwitcher` around the keyed map, with a `transitionBuilder` that combines `SlideTransition` (offset ±0.15 on x, with direction by chip index) and `FadeTransition`. Keep the `ValueKey(game)` on the child. Set the duration to `Duration.zero` when animations are disabled.
- [ ] **Step 4:** Run `flutter test test/features/levels`. Expected: PASS.
- [ ] **Step 5:** Commit with `feat(levels): animated game switch, aligned Sudoku chip, Path Words label`.

### Task 5: World labels — size range, visibility, clear of the dock

**Files:**
- Modify: `lib/features/levels/view/levels_screen.dart` (`_WorldLabel` at about line 529, `_worldLabel` at about line 316)
- Modify: `lib/features/levels/view/widgets/level_sheet.dart` (`levelBoardSize`). Add `levelBoardSizeRange(List<LevelEntry>)`.
- Test: `test/features/levels/view/levels_screen_test.dart`, `test/features/levels/view/level_sheet_test.dart`

**Interfaces:**
- Produces: `String? levelBoardSizeRange(List<LevelEntry> levels)`. It returns "5 × 5" when every level has one size, "3 × 3 – 6 × 6" when the sizes differ (smallest to largest), and null when no level has a size.

- [ ] **Step 1: Write failing tests.**
  - `levelBoardSizeRange`: same sizes give "5 × 5", mixed sizes give "3 × 3 – 6 × 6", and an empty list or missing sizes give null.
  - `a locked Path Words world's label is on screen`: with a two-world Path Words fixture (World 2 locked, mixed sizes), scroll the map until the World 2 gate is in the viewport. `find.text` containing "3 × 3 – 6 × 6" must be found, `hitTestable()`, and inside the screen rect.
  - `the bottom world's label sits above the dock`: after the first frame, the label's bottom edge is above `MediaQuery.padding.bottom` (the dock) of the test's viewport.
- [ ] **Step 2:** Run the tests. Expected: FAIL. First find out why the World 2 label isn't visible on the device, and write the cause in the commit message.
- [ ] **Step 3: Implement.**
  - The label uses `levelBoardSizeRange(world.levels)`.
  - Fix whatever keeps the gate label off-screen or under the header. Check the `FractionalTranslation` and `top: band.gateY` against the reversed scroll.
  - Make sure the current world's label, at rest after the scroll-to-current jump, isn't covered by the dock. Adjust the jump offset, or the bottom inset for the label.
- [ ] **Step 4:** Run `flutter test test/features/levels`. Expected: PASS.
- [ ] **Step 5:** Commit with `fix(levels): world labels show the size range and stay on screen`.

### Task 6: The goals bar keeps "Clear the board" on one line

**Files:**
- Modify: `lib/core/widgets/level_goals.dart` (`LevelGoalsBar`, from about line 151)
- Test: `test/core/widgets/level_goals_test.dart`, or wherever `LevelGoalsBar` is already tested (grep `test/`)

- [ ] **Step 1: Write a failing test.** `the three goals share one height and no label wraps alone`. Pump `LevelGoalsBar` at 360 px wide with a target time. Each goal's `Text` renders as a single line: check `tester.getSize(text).height` against the line height from one `TextPainter`. All three goal chips have equal heights.
- [ ] **Step 2:** Run the test. Expected: FAIL.
- [ ] **Step 3: Implement.** Use `IntrinsicHeight` with equal heights, and set each label to `maxLines: 1` with `FittedBox(fit: BoxFit.scaleDown)`, so text shrinks before it wraps. Large text scales may still wrap, but every chip must keep an equal height. Zip and Path Words both use this bar.
- [ ] **Step 4:** Run the test, then `flutter analyze` and the full `flutter test`. Expected: PASS, with 20 issues.
- [ ] **Step 5:** Commit with `fix(levels): goal chips stay on one line at an equal height`.

### Task 7: Check on the emulator (controller)

- [ ] **Step 1:** Hot restart the running app on `emulator-5554`.
- [ ] **Step 2:** Screenshot each item below. Unlock any locked world as needed with a debug-only local progress override; don't change the account or the backend.
  - each Path Words world, Animals and Food (open and locked);
  - each Zip world (Ink, Metro, Embroidery, Neon, Sparkler);
  - the header in both games;
  - the switch mid-animation;
  - the Sudoku tap;
  - a locked world label;
  - the in-game goals bar for Zip and for Path Words.
- [ ] **Step 3:** List any defects found, and fix them in one follow-up commit with a test where one is possible.
