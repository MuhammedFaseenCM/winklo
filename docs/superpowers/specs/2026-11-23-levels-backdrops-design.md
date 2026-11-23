# Levels backdrops, game switch animation and UI fixes — design

Date: 2026-11-23. Branch `feat/levels-backdrops`, from `master` at `bbc40b3`.
Builds on [Path Words Levels](2026-11-23-path-words-levels-design.md).

## Why

On the emulator, every Path Words world sits on a flat dark fill, so the map looks unfinished. Zip's later worlds (Embroidery, Neon, Sparkler) have the same problem once they open. Several smaller problems in the Levels header make the new switcher look rough:

- the Sudoku "Soon" chip is out of line with the other chips;
- switching games has no motion;
- locked Path Words worlds are drawn with Zip's metro lines.

## Goals

- **A drawn backdrop for every world theme.** Each one is drawn in code in the same style as Ink and Metro: a base colour plus a simple line or shape motif. It's sharp at any size, adds no image files, and is cheap to paint.
- **Path Words categories:**

  | Theme | Base | Motif |
  |---|---|---|
  | animals | dusk gradient, warm orange to plum | faint paw prints scattered along the band |
  | food | warm cream-red | faded gingham (crossed translucent stripes) |
  | sports | pitch green | white court lines: centre line, circle, box |
  | nature | deep teal | topographic contour lines with a few leaf dots |
  | home | muted slate-mauve | wallpaper diamond lattice, with wood-floor planks along the band's bottom |
  | body | soft rose on dark | floating cell bubbles (rings of different sizes) |
- **Zip themes still to do:** embroidery is a cross-stitch grid on linen-navy, neon is glowing tube strokes on near-black, and sparkler is star sparks on night blue. Ink and Metro stay exactly as they are.
- **Locked worlds show a faded preview of their own motif.** It is drawn as dashed or low-alpha lines on the app's ink colour, replacing the shared metro-line "unprinted" look for every theme. A theme without a motif keeps today's metro outline.
- **Path and node colours per theme.** The path stroke, the dots on locked segments and the node number colour must stay readable on every new backdrop, with contrast of at least 3:1 for the path and nodes against the base.
- **Switch animation.**
  - The orange selected pill glides to the chip you tapped.
  - The map slides sideways (Zip ← → Path Words) with a fade, in about 300 ms, using `Curves.easeOutCubic`.
  - With reduce-motion on (`MediaQuery.disableAnimations`), the change is instant.
- **Sudoku chip.**
  - Same height and baseline as the game chips.
  - Dimmed, with a small lock icon and "Sudoku · Soon".
  - Tapping it shows a snackbar: "Sudoku levels are coming soon". That copy goes in `AppStrings`, en and ml.
  - It is announced as a disabled button.
- **Chip label** reads "Path Words", not "Path". The three chips still fit on one line at the default text scale, and wrap cleanly at large text sizes.
- **The locked world label.** It shows the world's size range, for example "3 × 3 – 6 × 6", when the boards in a world differ in size, and it must be visible on the map. Investigate why it doesn't show today at the Path Words World 1/2 boundary.
- **The current world's name** stays above the nav dock and is never covered by it.
- **The in-game goal chips** (`LevelGoalsBar`) show all three goals on one line, or at an equal height, without "Clear the board" wrapping alone. This applies to both Zip and Path Words.

## Non-goals

- Image or illustrated assets.
- Animated (moving) backdrops.
- Changing Ink or Metro.
- Sudoku Levels.
- Any change to admin themes or the data layer: themes are read from the existing `world.theme`.

## Approach

- **Backdrops.** Split `WorldBackdropPainter` into one small painter function per theme, in a `backdrops/` folder under `levels/view/widgets/`, plus a palette per theme that the backdrop, path and node painters share (`LevelThemePalette.of(theme)`). Each motif is deterministic: positions come from the band rect and a fixed seed, so nothing jumps when the map rebuilds. Unknown themes keep the plain fill.
- **Animation.** `AnimatedSwitcher` (or an explicit `AnimationController`) around the keyed map, with a slide whose direction follows the chip order. The pill uses `AnimatedAlign` or `AnimatedPositioned` behind the chips.
- **Tests.**
  - A golden-free painter test per theme checks that it paints without throwing at small and large sizes.
  - A palette contrast test checks the 3:1 rule.
  - Widget tests cover:
    - the Sudoku chip's semantics and snackbar;
    - the animation with reduce-motion off and on;
    - the label's size range;
    - the dock inset.
- **Check on the emulator.** Afterwards, check every Path Words world (World 2 is reached by unlocking it on a test account, or through a debug override) and every Zip world.

## Left to the builder

- Exact colours and motif geometry, within the table above.
- Whether the pill is drawn as one moving shape or an `AnimatedContainer` per chip.

## Calls Claude made

- **Zip's Embroidery, Neon and Sparkler also get backdrops**, since they had the same blank fill.
- **Locked worlds show a faded version of their own motif**, not metro lines.
- **Reduce-motion turns the slide off.**
