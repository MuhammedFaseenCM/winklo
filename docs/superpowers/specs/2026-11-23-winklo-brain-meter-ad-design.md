# Winklo "Brain meter" ad (video D) — design

## Intent
A fourth vertical reel that follows the *plot* of a reference mobile-game ad the user supplied
(~/Downloads/ScreenRecording_10-31-2026…MP4, a "train your brain" puzzle ad for another app):
brain meter + hand cursor failing then solving, install beat, a "real person" beat, loop back.
Only the format is borrowed — no assets, names, art, labels or branding from the reference.

## Goals / non-goals / anti-goals
- Goals: ~30 s, 1080×1920, 30 fps; same family look as reels A–C; loops cleanly (last frame ≈ first).
- Non-goals: live-action footage, voiceover, an App Store badge (Winklo is Android-only).
- Anti-goals: copying the reference's look or wording (its meter labels, hand art, logo); fake claims
  (no "only 2% can solve" stats, no fake install counts).

## Beats (~30 s)
1. 0–2 s hook: header "Train your brain" + a horizontal brain meter (our labels, e.g.
   "Sleepy · Warming up · Sharp · Genius"), brain icon at the low end; empty Zip board below
   (shared/zip-puzzle.json). Frame 0 already shows all of this.
2. 2–7 s fail #1: a big cartoon hand (drawn fresh, Winklo style) traces the ribbon, steps across a
   wall → red shake + reject.ogg, ribbon clears, meter drops.
3. 7–12 s fail #2: the hand gets further, reaches a number out of order → red flash + reject, reset, meter dips.
4. 12–19 s solve: the hand traces the full legal solution (taps every few cells), meter climbs
   step by step to "Genius"; teal flash + success.ogg; "Genius!" pop.
5. 19–23 s install: real app_icon.png, a search bar that types "Winklo" letter by letter
   (tap ticks), then the official Google Play badge (unmodified, per Google's badge guidelines).
6. 23–27 s "real person": an animated phone held in a stylised hand, playing Zip on screen
   (ribbon drawing inside the phone), caption "Free daily puzzles".
7. 27–30 s loop: cross-fade back to the hook frame (empty board, meter low) so the reel loops.

## Constraints (same as reels A–C)
Palette/Lexend/app-gradient ribbon/light walls; words and boards inside y 168–1330; nothing read
under 28 px; music bed "Curiositys Arrival" (CC BY 3.0) at the A–C setup; mix −16..−14 LUFS,
true peak ≤ −1.5 dBTP; sfx from assets/sfx (CC0). Project marketing/videos/d-brain-meter/,
output marketing/videos/out/winklo-d-brain-meter.mp4. Fail moves must be genuinely illegal per Zip
rules (crossing a wall; number out of order), and the solve is the validated path.

## Approaches considered
- Phone-in-hand mockup for the live-action beat (chosen by user) vs user-filmed clip vs skipping it.
- ~30 s (chosen) vs matching the reference's 48 s.

## Revision 2026-11-23 (user feedback)
- Every reel gets its own Zip puzzle: A keeps `shared/zip-puzzle.json`; B, C, D use new validated
  puzzles `shared/zip-puzzle-b.json`, `-c.json`, `-d.json` (visibly different path shape, number
  positions and walls; no two share a wall set or numbered-cell set).
- Video D beats 2–4 become one attempt per meter level, and only Genius draws the correct path:
  - Sleepy attempt: wrong early — crosses a wall → red, reset.
  - Warming up attempt: further — reaches a number out of order → red, reset.
  - Sharp attempt: almost — fills most of the board then dead-ends (no legal next cell, cells
    left unvisited, highlighted) → red, reset.
  - Genius attempt: the full correct solve → teal flash, "Genius!".
  The meter jumps to each level *before* its attempt (the label "Sleepy…/Sharp…" visibly owns the
  try); wrong tries never climb past their level. Total length stays ≤ 32 s.
