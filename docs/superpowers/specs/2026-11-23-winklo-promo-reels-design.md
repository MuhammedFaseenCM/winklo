# Winklo promo reels — design

## Intent
Three short vertical promo videos for Winklo (Zip, Path Words, 6×6 Sudoku — daily, free, Android)
to post on Instagram Reels / YouTube Shorts / TikTok. Goal: stop the scroll and send people to the
Play Store listing.

## Goals / non-goals / anti-goals
- Goals: 9:16 1080×1920 MP4, 30fps; works with sound off (all key words on screen); matches the
  app's real look; ends on "Winklo — free on Android".
- Non-goals: voiceover, real screen recordings, 16:9 / store-preview cuts (can be adapted later).
- Anti-goals: anything that misrepresents the app (fake features, fake ratings or download counts);
  paid tools or paid assets.

## Constraints
- Free tools only: HyperFrames (Apache-2.0) + local ffmpeg.
- Brand: bg ink #0F172A, cards #243044, walls #1E293B, ember #FF6B2C (Zip line, CTA), sky #38BDF8,
  teal success #2DD4BF, star #FBBF24, number #FB7185. Font: Lexend. Logo: assets/branding/app_icon.png.
- Audio: app's own Kenney CC0 sfx (tap / success / clear) plus a music bed, "Curiositys Arrival" by Steven Booth (CC BY 3.0). Credit it in every post caption; see marketing/videos/shared/assets/music/CREDIT.md.
- Every word and every board inside the band y=168–1330px; below 1330 only decoration; no text under the
  right-hand action rail. Frame 0 is the hook (never black, never a logo). Nothing read under 28px.
- Lexend isn't bundled with HyperFrames: ship Lexend (OFL, Google Fonts) as a file in assets/fonts with @font-face.

## Approaches considered
- A — one Zip solve (~15s): strongest hook, loops well; other games get a flash only.
- B — three-game tour (~25s): shows everything; slower, more swipe-away risk.
- C — "beat my time" challenge (~20s): drives comments; narrower.
User chose: make all three, one at a time, A → B → C.

## The three videos
**A. "One line" (~15s)**
0–2s hook "Can you draw ONE line through every square?" over an empty 8×8 Zip board (numbered
dots, a few walls). 2–10s ember ribbon draws the full solution path, hitting 1→N in order, tap
ticks. 10–12s board flashes teal, timer stops, "Solved 0:47" + leaderboard rank chip. 12–15s quick
flash of Path Words + Sudoku boards → "3 free puzzles. Every day." → logo + "Free on Android".

**B. "3 puzzles a day" (~25s)**
Hook "3 puzzles. Every day. Free." → ~5s each: Zip ribbon solve, Path Words word traced through
letter grid (word pops), 6×6 Sudoku cells filling to teal → feature beats (daily leaderboard,
streak flame, "hints cost time, never lock you out +10s") → logo CTA.

**C. "Beat my time" (~20s)**
"Today's Zip. Beat my time." with a big running clock → fast solve with the clock ticking →
stops at 0:47 → "Your move." → logo + "Free on Android · new puzzle at midnight".

## Builder's calls
- Zip puzzle layout is a hand-made valid 8×8 Hamiltonian path (needn't be a real daily board).
- Exact timings, easing, transitions and leaderboard numbers within the beats above.
- Output: marketing/videos/<name>/ (project) with final MP4s in marketing/videos/out/.
