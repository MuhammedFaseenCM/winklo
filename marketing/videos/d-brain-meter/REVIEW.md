# REVIEW: Video D "Brain meter"

1080×1920, 30 fps, 30.0 s. Output: `../out/winklo-d-brain-meter.mp4` (6.3 MB).

## Creative calls
- Beats:
  - brain scene 0–19 s: hook, fail #1, fail #2, solve, Genius
  - install 19.0–23.4 s
  - phone 23.4–30.0 s, with the loop cross-fade at 29.2–29.9 s
- The plot follows the reference ad (meter, a hand that fails and then solves, install, "real person", loop). Nothing else is taken from it. The labels are "Sleepy · Warming up · Sharp · Genius". The brain (pink lobes with a face) and the pointer hand (peach, ink outline, ember cuff) are our own vector art, drawn in `tools/build.mjs`.
- Hook (frame 0) shows:
  - "Train your **brain**" at 92 px, with "brain" in ember
  - the meter, with the brain at "Sleepy"
  - the empty Zip board (780 px, y 530–1310)
  - the hand resting on "1"

  At 0.5 s the hand presses "1", with an ember ring and a tick.
- **Fail #1** is computed from `tools/zip-puzzle.json`. It is the earliest path cell (after at least 3 steps) that has an unvisited neighbour behind a listed wall. That gives 18 true steps to "3", then (7,2)→(7,3) across wall 3.
  - The hand hesitates for 0.3 s before the bad step.
  - On frame 127 (4.22 s):
    - the offending segment turns red (#F87171), as does the crossed wall
    - a red ring circles the wall
    - the board shakes (8 px, damped)
    - reject.ogg plays
    - the brain frowns and wobbles
    - the hand recoils off the move
  - Then the ribbon wipes back to empty, with the hand riding the tip home, and the brain slides from "Warming up" down to the left end.
- **Fail #2** is also computed. From the furthest path cell before number k+1, a BFS finds a short detour through free cells that reaches k+2 first. That gives 26 true steps, then (5,3)→(6,3)→(7,3)→(7,4), which lands on 5 before 4.
  - On frame 289 (9.62 s), the last segment turns red, "5" turns red with a red ring, and the shake and reject play.
  - Then the wipe back and the meter drop.
- Proofs in `build.mjs`:
  - `firstViolation()` replays the Zip rules (start on 1, adjacency, walls, no revisits, numbers in order).
  - The build throws unless fail #1's first violation is a wall on its last step, and fail #2's is an out-of-order number on its last step.
  - It also throws unless fail #2 gets further than fail #1, and unless the full path is legal.
- **Solve** draws all 63 steps from 11.34 to 16.96 s (C's half linear, half smoothstep ease).
  - The meter climbs one step per number reached (2…8), with a small back-ease overshoot, to "Genius".
  - On frame 509:
    - teal flash, ring and board bump
    - success.ogg
    - the brain bobs
    - the "Genius" label turns teal
  - "Genius!" (140 px, teal pill) pops at 17.08 s and holds about 1.5 s. The hand leaves down and right. The board then falls away (18.55–18.95 s).
- The hand cursor rides the ribbon tip in every trace. It is 127×155 px, about 8% of the frame height. It lifts and grows 7% when it isn't pressing.
- **Install**:
  - the real `app_icon.png` at 300 px
  - a white rounded search bar: the hand taps it, then "Winklo" types in at one letter per 0.12 s, with a tap tick per letter
  - the official Play badge (`assets/badges/google-play-badge.png` with its README, unmodified) at 560 px wide, height auto, uniform scale only. It pops in and the hand taps it.
  - C's ember "Free on Android" pill
  - There is no App Store badge.
- **Phone**:
  - "Free **daily** puzzles" (86 px)
  - a phone (rounded body, notch) held in a stylised hand: the palm behind, four fingers wrapping the right edge, the thumb over the left edge, and an ember cuff below y 1330 as decoration
  - a slow handheld sway (±1.2°)
  - on the screen, the mini Zip board (560 px, so its numbers render at 28 px) draws the ribbon from 24.3 to 27.3 s, then a teal flash and a "Solved" chip, with a quieter success sfx
- **Loop**: the phone scene contains a copy of the hook frame built by the same `brainHtml` and `render(0)` code. It cross-fades in from 29.2 to 29.9 s, so the last frame is the hook.
- Transitions:
  - one continuous board through beats 1–4
  - fall away + blur (brain → install)
  - blur swap (install → phone)
  - cross-fade into the hook (loop)
- Audio:
  - Kenney CC0 sfx: a hook tap; taps every 4 steps (4 + 7 + 15); 2× reject; success; a "clear" pop on Genius and on the badge; a bar tap, 6 key ticks and a badge tap; a soft success in the phone.
  - Music: `<audio id="music">` on its own lane (4), 0–30 s, volume 0.8, fades of 0.2 s in and 1.5 s out.
  - The sfx trims are lower than C's (tap ×0.6, success ×0.55, clear ×0.6, reject ×0.42; tap volumes rotate 0.5/0.7/0.6/0.75). At C's levels, this mix measured −16.2 LUFS and −1.1 dBTP. The peaks were a solve tap over a music transient at 15.0 s and reject-2.
- `tools/build.mjs` generates every HTML file. Running it again overwrites edits made in Studio.

## Measured vs looked at
- `check --json`: ok, **0 errors**. Warnings: 13 `line_unread`, 7 `outside_safe_zone`, 2 `composition_file_too_large` and 1 `content_overlap`, plus 3 `text_occluded` (info). See "Warnings kept" below.
- `snapshot --review`: I looked at the beat sheet, 2 seams and the phone sheet. I also took extra snapshots at 0, 4.25, 4.3, 9.65, 9.75, 13.5, 17.1, 17.6, 21.6, 26, 29.5, 29.75 and 29.95 s.
- ffprobe: 1080×1920, 30/1 fps, 30.000 s, with video and audio streams.
- `audio --json` on the MP4: **−15.9 LUFS integrated, true peak −2.1 dBTP**, no clipping, no silence. The loudest 0.1 s windows are 17.2 s (success and pop, −2.2 dB), 15.0 s and 9.6 s (reject).
- Frames pulled from the MP4 into `review-frames/` (git-ignored) and looked at:
  - f0: hook
  - f127: fail #1 red frame
  - f289: fail #2 red frame
  - f405: mid-solve
  - f528: Genius!
  - f648: install with the badge
  - f780: phone
  - f899: last frame
- Loop check: an ffmpeg SSIM of the first frame against the last is **0.9965** (All).
- **I measured the sound but never heard it.**

## Fixes from review
- P0: none on the sheets.
- P1, fail #1: the hand covered the red step and the wall. On a fail, the hand now recoils (+70, +120 px) until the wipe starts, and the red ring is centred on the crossed wall, not on the cell.
- P1, phone: the thumb read as a detached stick. The palm now extends past the phone's left edge and the thumb grows out of it. The skin shapes have a darker skin-tone outline, so they read on the dark ground.
- Layout: the header moved to y 188 so its box clears 168. The loop cross-fade overlap is marked `data-layout-allow-overlap`.

## Warnings kept, and why
- `line_unread` (×13): every one is on the loop layer (`#loop-*`), which is on screen for only 0.43 s at the end. That is intended: it is a copy of frame 0, which the viewer reads when the reel loops.
- `outside_safe_zone` (×7): same cause as A–C. The CLI's TikTok, Reels and Shorts boxes are stricter than the spec's binding band (y 168–1330). All text and both boards are inside that band.
- `composition_file_too_large` (×2): `brain.html` and `phone.html` are generated (one pure `render(t)` each). They are not hand-edited.
- `content_overlap` (×1, warning): the phone's "TODAY'S ZIP" under the loop layer during the cross-fade. Intended.
- `text_occluded` (info): the numbers under the "Genius!" pill. Intended.

## Weakest shot
The install beat. The badge is 560 px on a dark, mostly empty frame. The hand tapping it reads as staged, and the dark app icon sits low-contrast on the dark ground. With more time, I'd put the icon, name and badge on one Play-style listing card, so the beat reads as a store page.

## Credits
Music: "Curiositys Arrival" by Steven Booth (CC BY 3.0). This credit must go in the caption wherever the reel is posted.
Sfx: Kenney Interface Sounds (CC0).
Google Play and the Google Play logo are trademarks of Google LLC. The badge is used unmodified, per Google's badge guidelines.

## Fix round 1
- Badge never covered. The hand now taps just outside the badge's bottom-right corner (+34, +30 px), with a small ember press ring. The badge stays unmodified at 560 px, with no press scale. Checked on frames 630, 648 and 660 and on a `snapshot --range 19,30` sheet.
- Install beat:
  - The app icon now sits on a lighter rounded backing tile (#2A3A57, 336 px) with a thin light ring and a soft ember glow, so the tile edge reads.
  - The stack (tile, bar, badge, pill) is computed and centred inside y 168–1330 (tile top 245, pill bottom 1253). The build throws if it leaves the band.
- Phone beat:
  - The mini board is now 600 px and fills the screen width, so its numbers render at 30 px.
  - A 60 px in-game clock counts 0:00→0:47 with the line and turns teal on the solve.
  - An app tab bar (three tiles, Zip lit) fills the bottom of the screen. It is decoration, below 1330.
  - The fingers are stacked, touching, and overlap the bezel by 54 px. The palm shows past the right edge, so the fingers connect to it.
- Re-measured:
  - `check --json` is ok with 0 errors. The new cross-fade overlap on `#ph-clock` is marked `data-layout-allow-overlap`.
  - ffprobe: 1080×1920, 30 fps, 30.000 s, 6.75 MB.
  - `audio --json`: −15.9 LUFS, −2.1 dBTP.
  - First-vs-last-frame SSIM: 0.9965.
- Weakest shot now: the install beat's hand tap is still staged, though it no longer hides anything.
