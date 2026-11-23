# REVIEW — Video B "3 puzzles a day"

1080×1920, 30 fps, 25.8 s. Output: `../out/winklo-b-three-a-day.mp4` (3.6 MB).

## Creative calls
- Beats: hook 0–2.2 s · Zip 2.2–7.4 · Path Words 7.4–12.8 · Sudoku 12.8–18.2 · features 18.2–23.3 · CTA 23.3–25.8.
- Hook. Frame 0 already shows "3 puzzles. / Every day. / Free." in white, ember and teal, with the three empty boards (400 px each) dealt underneath like a hand of cards: Zip in front in the centre, Path Words and Sudoku tilted ±6° behind it, labels at y 1168. At 0.9 s a ring picks Zip, with a tick. At 1.55 s the Zip mini-board grows into the full stage (carry across) while the other two clear.
- Each game gets a "PUZZLE n OF 3" kicker plus its name in that game's colour (ember, sky, teal, as in video A). The boards are 840 px at y 480–1320.
- Zip uses the board, walls and real ribbon gradient copied from video A, and its own puzzle (`tools/zip-puzzle.json`, copied from `shared/zip-puzzle-b.json`). The ribbon draws all 63 steps in 3.65 s, then a teal flash, a ring and a "Solved" chip.
- Path Words copies `path_words_game.dart`. Cells with no letter get the ink 72% wash and there are grid lines. Path cells are inset 10% with an 18% radius and the `_fillColor` of sky (#1A7CA7) with a white 18% stroke. A white start ring sits on P. PUZZLE (P-U-Z ↓Z ↓L-E) grows cell by cell from the side the trace enters. On "found" the letters pop, the board gets a teal glow and a "✓ PUZZLE" chip lands. I used sky (palette index 1) rather than rose (index 0) so Path Words stays sky across the family.
- Sudoku copies `sudoku_game.dart`. The board is paper at 92%, with thick box lines (white 55%) every 3 columns and every 2 rows. Givens are white 700, filled digits sky 600, and a sky 22% selection steps to each cell before it fills. Nine cells fill. Row 2 completes and gets a teal wash, then the bottom-right 2×3 box does the same, then the whole board washes teal (solved). `tools/build.mjs` throws unless every row, column and 2×3 box is 1–6 unique, and unless the row and box complete exactly on the fill that triggers their flash.
- Features run one at a time, each line ≤5 words:
  - "Daily / leaderboard": a Today's Zip card with the "#3 You 0:47" row popping. The names are illustrative.
  - "Keep your / streak": a star-gold flame, the count rolling 11→12, "day streak", and a week of dots.
  - "Hints cost time, / not lockouts": the hint button is tapped, a "+10s" chip pops and the clock jumps 0:47→0:57. This matches `domain/hint_penalty.dart`, where the first hint costs +10 s and there is no cap.
- CTA: the real `app_icon.png`, "Winklo" and an ember "Free on Android" pill, with "3 puzzles. Every day." echoing the hook. It lands at about 23.4 s and holds 2.4 s.
- Transitions: carry across (hook→Zip), blur swap (Zip→Path Words), horizontal whip (Path Words→Sudoku), zoom out and fall away (Sudoku→features), blur swap (features→CTA).
- Music bed: "Curiositys Arrival" by Steven Booth (CC BY 3.0), a 32 s excerpt that opens on its strong section (`assets/music/CREDIT.md`). It is `<audio id="music">` on its own lane (4), runs 0–25.8 s at volume 0.72 (the bed sits around −17 LUFS), and fades in over 0.2 s and out over 1.5 s.
- Sfx are Kenney CC0 and play over the bed. Solves are trimmed ×0.62 and "clear" pops ×0.7; taps are as placed:
  - a tick at 0.93 s
  - 7 Zip taps
  - a tap for each traced Path Words cell
  - a tap for each Sudoku fill (rotating volumes)
  - "clear" as the pop for the word chip, the row and box flashes, the three feature pops and the logo
  - "success" on each of the three solves
- `tools/build.mjs` generates every HTML file from `tools/zip-puzzle.json`, a copy of `../shared/zip-puzzle.json`. Re-running it overwrites Studio edits.

## Measured vs looked at
- `check --json`: 0 errors.
- Snapshot review sheets looked at: beats, 5 seams and phone width. So were extra snapshots at 6.6, 9.0, 16.4, 19.4, 21, 22, 22.7 and 25.5 s, plus 8 frames pulled from the MP4 (`review-frames/`, git-ignored).
- ffprobe: 1080×1920, 30/1 fps, 25.80 s, with audio.
- `audio --json` (with music): −15.8 LUFS integrated, true peak −1.0 dBTP, no clipping. Sound is present the whole length; the only silence is the last 0.28 s, where the fade-out ends. Estimated from the envelope, the sfx peaks sit a median of about 4 dB over the bed. That estimate is rough: the bed is percussive and the taps are 10 ms clicks. **I measured the sound but never heard it.**

## Fixes from review
- P0: the Sudoku wash selectors broke the scene script (nested double quotes). They now use single quotes.
- P1: the "+10s" chip floated under the hint card. It now sits as a badge on the card's top-right corner.
- P2: the whip seam at 12.8 s had a blank frame. The Path Words exit now starts 0.03 s later and Sudoku enters at 50% opacity.

## Warnings kept, and why
- `outside_safe_zone` (×37): the same cause as video A. The CLI's TikTok, Reels and Shorts models are stricter than the spec's binding band (y 168–1330). The kickers start at 196 px. The bottom rows and right columns of the boards fall outside the conservative platform boxes. Everything is inside the spec band.
- `container_overflow` (info): the Sudoku board starts 700 px off to the right for the whip. This is intended.
- The hook's mini-boards are `data-layout-ignore`. Their glyphs are pictures of boards, not copy. The game names under them are 40 px.

## Fix round 1
- Feature visuals scaled about 1.35× and centred in y 470–1330:
  - leaderboard card 920 px wide with 140 px rows
  - flame 460×540, the count at 310 px, 120 px week dots
  - hint card 920×440 with a 300 px button and a 200 px clock, plus a 460×200 "+10s" badge with 132 px type
- The leaderboard card now lands as one piece with rows 1, 2 and 4 already in it. Only "#3 You" pops in.
- The hint beat is now one sequence: the button is pressed and the bulb lights up, then the clock jumps 0:47→0:57 in rose, then the big "+10s" badge drops in under the card.
- I narrowed the cards to 920 px (x 80–1000) so the times stay off the right-rail edge as much as possible.
- Hook mini-boards: about 1.27× larger and fanned. They now reach y≈1215, against ≈1060 before.

## Weakest shot
The hook's fanned boards. The Zip card covers the inner columns of Path Words and Sudoku, so those two read mainly through their visible edges and labels. The feature beats now fill the band.

## Not built
Storyline C ("Beat my time") is a separate task.

## Credits
Music: "Curiositys Arrival" by Steven Booth (CC BY 3.0). This credit must go in the caption wherever the reel is posted.
Sfx: Kenney Interface Sounds (CC0).
