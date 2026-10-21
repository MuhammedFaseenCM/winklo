# App promo video: real screens, 45 s hype cut (design)

2026-10-21. A promo for YouTube and the Play Store listing that shows the app as it ships in
1.1.4+23: the Leaderboard podium, the Phosphor duotone icons, the Results scoreboard and the
critter avatars, plus the three daily games.

Decisions (agreed 2026-10-21): **real screens, animated** (not a phone recording, not canvas
re-creations) · **45 s, one cut** (24 bars at 128 BPM) · the hype set's look and sound
(`~/Desktop/winklo-playstore/hype-kit`, impacts at `Scene.IMPACT`).

## How it's made

1. **Capture** (`tool/promo_capture/`, this repo). A `flutter test` file pumps the real
   `WinkloApp` (real router, real screens, real Flame games) with fixed puzzles, a signed-in
   player and fake leaderboard streams, and drives it like a player: taps, and drags through
   cell centres. Each shot is recorded at 60 fps at 3× (1170×2532): `RenderRepaintBoundary.toImage`
   → raw RGBA → piped into ffmpeg → JPEG frames. Every event is placed on the same 128 BPM grid as
   the score (`T(bar, beat, sixteenth)`), so the app's own animations land on the beat.
   - Fonts: real Lexend (static weights from Google Fonts, downloaded to the media folder, not
     committed), the vendored Phosphor fonts, Material icons.
   - Network images (game tiles, medals) are the real R2 PNGs, seeded into Flutter's
     `imageCache` under their `CachedNetworkImageProvider` keys.
   - The view has a 36 dp top and 16 dp bottom inset so the screens lay out as on a phone; the
     compositor draws a status bar into the top inset.
   - Names on the boards are invented. No real player appears.
   - The Flame boards paint their numbers and letters outside the theme, and the test engine draws
     its default font as boxes. A test-only hook, `BoardText.family` (null in the app), lets the
     capture give them Roboto, the phone's sans.
   - The run clock is a debug-only label (release shows nothing), so the capture blanks it.
   - A `manifest.json` lists every shot (start time on the grid, frame count) and every touch
     (time, position), so the compositor can show touch ripples.
2. **Compositor** (`~/Desktop/winklo-playstore/app-promo/`). A canvas renderer like the other
   hype spots: the captured frames inside a drawn phone, camera moves (push-ins on the board),
   stamped Lexend copy, flashes, shockwaves, beams and the shared end card. Headless Chrome is
   started from the shell (Chrome 155 workaround); frames are piped to ffmpeg. 1920×1080 and
   1080×1920, 60 fps.
3. **Score** (`audio.js`): the hype kit's instruments in A♭ major (Fm – D♭ – A♭ – E♭), stretched to
   24 bars, normalised to −14 LUFS / −1 dBTP by `mux.sh`.

## Storyboard (24 bars, 45.0 s)

| Bars | Time | Shot (real screens) | Copy |
|---|---|---|---|
| 0–1 | 0.0 | Hook: phone slams in on **Home** (three daily games, Phosphor icons); a tap on "Play today's Zip" | "3 puzzles." "Every day." |
| 2–5 | 3.8 | **Zip** 8×8: the line runs from the 1, eighths → sixteenths → thirty-seconds; camera pushes in. Breath on bar 5 beat 3, one cell short | "One line." "Every cell." "Connect 1 → 7. Mind the walls." |
| 6 | 11.3 | **Drop**: the last move connects; the game's own win | "Cleared." + chip "0:48 · Hint-free" |
| 7 | 13.1 | **Results scoreboard** (0:48, "#4", streak / PB / hint-free tiles) | "See where you rank." |
| 8–9 | 15.0 | **Path Words**: five words traced on sixteenths, each lights in its colour | "Find the hidden words." "Then spot the theme." |
| 10–11 | 18.8 | **Sudoku** 6×6: the last cells filled on the beat, a flawless clear | "Sudoku, 6×6." "Flawless." |
| 12–13 | 22.5 | Break: Leaderboard dims while it loads; breath on bar 13 beat 3 | "Same puzzle for everyone." "How fast are you?" |
| 14–16 | 26.3 | **Drop 2**: the podium lands on the downbeat; game tabs Zip → Path → Sudoku on bars 15 and 16 | "Climb the podium." "Daily, weekly and all-time." |
| 17–18 | 31.9 | **Critters**: Profile → avatar sheet → tap the tiger → saved | "Pick your critter." "12 to choose from." |
| 19–20 | 35.6 | **Streak**: Home with all three cleared ("Perfect day") on a 7-day streak, as in the carousel | "Keep the streak alive." + flame "7-day streak" |
| 21–23 | 39.4 | End card (shared `Scene.drawEnd`): icon slam, Winklo, "One puzzle. Every day. Beat the clock.", Zip · Path Words · Sudoku | |

## Rules carried over

- Zip is 8×8 with walls (the Instagram carousel's unique board); Sudoku is 6×6 with 2×3 boxes;
  Path Words words follow the global-audience rule (no India-only words or loanwords).
- Play policy: no "#1", "Best", "Top", "Free", "New", ratings, prices or store badges in the
  copy. The in-app "#4" is the player's rank on the board shown, not a claim about the app.
- Copy in sentence case, Lexend 800, no wide-tracked uppercase.

## Outputs

`~/Desktop/winklo-playstore/app-promo/`: `winklo-app-promo-1920x1080.mp4` (Play promo slot via
YouTube, YouTube), `winklo-app-promo-1080x1920.mp4` (Shorts, Reels), `soundtrack.wav`,
`youtube.txt` (title, description, tags) and `thumbnail-1280x720.png`.

## Verification

- Capture: every shot's first, middle and last frame checked by eye (Lexend, icons, images, no
  overflow or debug banners); Zip and Sudoku runs end in the app's real clear state.
- Video: stills at every section boundary in both formats, tiled into contact sheets.
- Score: per-bar RMS follows the energy curve; both breaths are silent apart from the reverse
  cymbals; loudness −14 LUFS integrated, true peak ≤ −1 dBTP.
