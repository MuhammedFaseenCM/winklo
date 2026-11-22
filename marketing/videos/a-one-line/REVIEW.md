# REVIEW — Video A "One line"

1080×1920, 30 fps, 16.6 s. Output: `../out/winklo-a-one-line.mp4`.

## Creative calls
- Beats: hook 0–2 s (text + empty board, a ring lands on "1" at 0.9 s) · solve 2–10 s (ribbon draws all 63 steps, `power1.inOut`, clock 0:00→0:47 tied to progress) · payoff 10–12 s (teal flash + ring, "Solved / 0:47", "#3 today" chip) · CTA 12–16.6 s (the solved Zip board shrinks into the first of three slots, then Path Words and Sudoku land beside it, each labelled; all three sit together under "3 free puzzles. / Every day." from about 12.85 to 14.05 s; then the logo lockup).
- The board copies the app's own painter (`lib/features/zip/game/zip_game.dart`): #1E293B board, #475569 outline, cells as #243044 rounded tiles, near-white wall bars, #FB7185 numbers that turn white with an ink outline once the line reaches them. The ribbon uses the app's real gradient (`ZipPathRibbon`: ember → gold → rose → orchid every 4 cells), which starts on ember #FF6B2C. That's a deliberate change from "solid ember" so the video matches the app.
- The hook text carries over into the solve scene and stays until 2.6 s, so a 9-word hook gets about 2.6 s to read. The ribbon starts at 2.15 s underneath it.
- Total length is 16.6 s. The lockup lands at 14.35 s and holds about 2.2 s.
- Sound: Kenney CC0 sfx only, no music (no free source configured). One quiet tick at 0.93 s when the ring lands on "1". 15 tap ticks, one every 4 steps, with volume rotating between 0.55, 0.8, 0.65 and 0.9. Success on the solve (10.03 s), "clear" as the pop on the rank chip (10.47 s, peak at about 10.63 s) and on the logo (14.22 s). Two quiet taps as the Path Words and Sudoku slots land.
- `tools/build.mjs` generates every HTML file from `../shared/zip-puzzle.json`. Running it again overwrites edits made in Studio.

## Measured vs looked at
- `check --json`: 0 errors. Snapshot review sheets (beats, 3 seams, phone) looked at. Five frames pulled from the MP4 and looked at.
- `audio --json` on the MP4: sound present, onsets at the tick, solve, chip, card and logo times, −12.9 LUFS integrated, true peak −1.0 dBTP. **I measured the sound but never heard it.**

## P0s fixed in review
- The Path Words trace was drawn over the letters and hid them. It now sits between the tiles and the letters.
- The Sudoku digits popped from the wrong transform origin and landed offset in their cells. They now pop with an attribute font-size tween.
- The ribbon tip was black on its first frame because `colorAt(0)` returned an array. It also scaled from a bad origin. Both are fixed (`svgOrigin`).
- P1: number "1" turned white at the 2.0 s seam before the line existed. It now waits for the line. The hook text was crowding the board, so I shrank it (66/110/66 px).

## Warnings kept, and why
- `outside_safe_zone` (×19): the CLI's TikTok, Reels and Shorts models are stricter than the spec's binding band (y 168–1330). The top text starts at about 182 px, the board's bottom row is near 1250–1300 px, and column 7 crosses TikTok's conservative right-rail box. Everything is inside the spec band. Meeting all three models at once would shrink the board to about 660 px.
- I marked the mini boards' glyphs in the CTA `data-layout-ignore`. They are pictures of game boards, not copy. The game names under them are 40 px.

## Weakest shot
The three-games row. The boards are small (316 px each, held to the canvas width), so the glyphs inside them are texture. The games read through their shapes and their 40 px names. The space below the row (about 1000–1330 px) is empty during that beat.

## Not built
Storylines B ("3 puzzles a day") and C ("Beat my time") are separate tasks.
