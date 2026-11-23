# REVIEW — Video C "Beat my time"

1080×1920, 30 fps, 19.8 s. Output: `../out/winklo-c-beat-my-time.mp4` (2.1 MB).

## Creative calls
- Beats: hook 0–1.6 s · solve 1.6–12.2 · "Your move." 12.2–15.2 · CTA 15.2–19.8.
- Hook. Frame 0 already shows "Today's Zip." (66 px, white) over "Beat my time." (112 px, ember) and a clock reading 0:00 (132 px), all above the empty board. At 0.8 s an ember ring lands on "1" with a tick. The ring fades by 1.57 s.
- Board. It uses the Zip board, light walls and real ribbon gradient (#FF6B2C → #FFC53D → #FF4D6D → #E879F9) copied from A and B, with its own puzzle (`tools/zip-puzzle.json`, copied from `shared/zip-puzzle-c.json`). The board is 780 px (y 540–1320) instead of 840, to make room for the big clock above it.
- Solve. The ribbon draws all 63 steps from 1.9 to 10.69 s, which is 8.8 s. The ease is half linear and half smoothstep, so the clock never stalls at either end. The clock carries over from the hook position: it rises and grows to 220 px Lexend 700 between 2.05 and 2.55 s, while the hook copy blurs away and a "TODAY'S ZIP" kicker fades in. The displayed seconds are `floor(47 · p / 63)`, where p is ribbon progress. The clock runs faster than real time.
- Solve frame. The draw ends at 10.69 s, a third of a frame before frame 321 (10.700 s). That makes frame 321 the first frame with p = 63 whatever the float rounding. `tools/build.mjs` throws unless frame 320 reads 0:46 and frame 321 reads 0:47. On frame 321 the clock turns teal and pops (a damped spring, peak ×1.16), a teal flash covers the board, a teal ring locks on and the board bumps. The kicker then swaps to "SOLVED". The success sfx peaks one frame later.
- The whole solve scene is a pure `render(t)` driven by one linear tween over the scene. The flash and pop therefore never depend on how GSAP reverts tweens on seek-back.
- "Your move.": 0:47 stays dead still in teal under "SOLVED" as the time to beat. The solved board falls away (y +220, blur, 0.42 s `power3.in`). "Your" (white) and "move." (ember) slam in at 236 px (scale 1.45→1, blur 14→0, `expo.out`, 0.14 s apart), with a "clear" pop as "move." lands. The line holds about 2.2 s.
- CTA: the lockup from B (real `app_icon.png` at 320 px, "Winklo" at 132 px, ember "Free on Android" pill), plus "New puzzle at midnight" at 60 px. It lands at about 15.3 s and holds 4.5 s.
- Transitions: carry across (hook→solve, the clock is one continuous object), fall away (solve→move), blur swap (move→CTA).
- Audio: Kenney CC0 sfx over the music bed, with the same per-sound trims as B (success ×0.62, clear ×0.7):
  - a hook tick at 0.83 s
  - 15 path taps, one every 4 steps, volumes rotating 0.55/0.8/0.65/0.9
  - success at 10.733 s
  - "clear" pops on "move." and on the logo
- Music: "Curiositys Arrival" (`assets/music/CREDIT.md`). It is `<audio id="music">` on its own lane (4), runs 0–19.8 s at volume 0.78, and fades in over 0.2 s and out over 1.5 s.
- Level changes from B, made to hit the targets for this reel:
  - Music volume is 0.78, against 0.72 in A and B. At 0.72 the mix measured −16.2 LUFS.
  - Taps get an extra ×0.72 gain. At full gain the 0.9 taps peaked at −1.2 dBTP.
- `tools/build.mjs` generates every HTML file. Running it again overwrites edits made in Studio.

## Measured vs looked at
- `check --json`: 0 errors, 16 warnings (all `outside_safe_zone`, see below).
- Snapshot review sheets looked at: beats, 3 seams and phone width. So were extra snapshots at 10.667, 10.7, 10.8, 11.3, 1.5, 15.167, 15.2 and 15.233 s.
- ffprobe: 1080×1920, 30/1 fps, 19.80 s, with video and audio streams.
- `audio --json` on the MP4: −15.6 LUFS integrated, true peak −2.4 dBTP, no clipping, no silence.
- Frames pulled from the MP4 into `review-frames/` (git-ignored) and looked at:
  - frame 0 (hook)
  - frame 180 (mid-solve, 0:21)
  - frame 320 (0:46)
  - frame 321 (0:47, teal, flash)
  - frame 420 ("Your move.")
  - frame 555 (CTA)
- **I measured the sound but never heard it.**

## Fixes from review
- No P0s.
- P1: the seam into the CTA had a blank frame. The move exit now starts at 2.82 s and the CTA logo starts at 30% opacity at t=0.
- P2: the hook ring now fades before the seam. Before, it vanished on the cut.
- Info: the `content_overlap` flag on the TODAY'S ZIP/SOLVED crossfade is intended. `data-layout-allow-overlap` is on the kicker.

## Warnings kept, and why
- `outside_safe_zone` (×16): the same cause as A and B. The CLI's TikTok, Reels and Shorts models are stricter than the spec's binding band (y 168–1330). The hook copy starts at 180 px, the kicker sits at 196 px, the board's bottom row is near 1270 px and its right column is near TikTok's rail box. Everything is inside the spec band.

## Weakest shot
"Your move." The board is gone, so the frame below y≈1130 is empty while the words hold. With more time, I'd keep a faded and shrunken board (or the empty board for "your" turn) behind the line.

## Credits
Music: "Curiositys Arrival" by Steven Booth (CC BY 3.0). This credit must go in the caption wherever the reel is posted.
Sfx: Kenney Interface Sounds (CC0).
