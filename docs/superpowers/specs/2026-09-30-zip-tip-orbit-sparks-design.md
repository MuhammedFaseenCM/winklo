# Zip tip orbit sparks — Design

**Date:** 2026-09-30  
**Status:** Approved for planning  
**Scope:** Soft ember flecks that orbit the live Zip stroke tip while the user is drawing; stop immediately on release.

## Goal

Add a light sparkling feel to Zip drawing without changing puzzle rules, Bloc state, or post-win celebration. Sparks exist only at the rounded live tip while the finger/pointer is held down.

## Non-goals

- Trail / wake behind the tip
- Burst on cell enter or on win (win glow stays as today)
- White glitter / star style
- New packages (confetti, Lottie, Rive, Flame particle systems)
- Flutter overlay widgets over `GameWidget`
- Sparks in read-only solution view

## Behavior

| State | Sparks |
| --- | --- |
| Pointer down + `_drawing` + live tip present | ~8 soft warm flecks orbit the tip |
| Pointer released / draw ended | Cleared immediately (no post-lift fade) |
| Idle, won (not drawing), read-only | None |

Orbiting flecks follow the clamped live tip each frame (same position as `_drawTip`).

## Architecture

**Approach:** Canvas flecks inside `ZipGame` (same render path as the stroke).

1. Helper `lib/features/zip/game/zip_tip_sparks.dart` — pure particle model + canvas draw (keeps `zip_game.dart` focused; unit-tested).
2. `ZipGame.update(dt)` advances orbit angles while `_drawing`.
3. `ZipGame.render` draws sparks after `_drawPathStroke` so they sit on top of the tip.
4. When `_drawing` becomes false, clear the particle list.

No Bloc/event changes. Visual-only game layer.

### Particle model (helper)

Each fleck holds:

- base angle + angular speed (gentle, varied)
- orbit radius factor (~1.1–1.6 × tip radius)
- size (~1.5–3.5 logical px)
- color from Zip ribbon / ember family (`ZipPathRibbon` / `ZipColors.ember`)
- soft alpha (~0.35–0.75)

Spawn fixed set (~8) when drawing starts (or ensure list is non-empty on first draw frame). Do not grow unboundedly while dragging.

## Look & motion

- Soft ember / warm flecks matching the Zip path ribbon palette
- Orbit / float around the tip (stay near the tip circle)
- Subtle motion — readable, not frantic
- No large celebration burst; continuous low-key sparkle while held

## Testing

- Unit tests on helper (or thin game-facing API):
  - empty / inactive when not drawing
  - non-empty while drawing with a tip
  - cleared after stop
- Existing Zip draw / stroke tests remain green
- No golden screenshot requirement for this polish

## Success criteria

1. Holding and dragging the Zip path shows soft warm flecks orbiting the tip.
2. Lifting the finger removes sparks immediately.
3. Puzzle logic, win flow, and read-only board are unchanged.
