# Promo capture

Records the real app, frame by frame, for promo videos. `promo_capture_test.dart` pumps the whole
`WinkloApp` (real router, screens and Flame games) as a signed-in player with fixed puzzles and
invented leaderboards, plays it with taps and drags on a 128 BPM grid, and writes each shot as 60 fps
JPEGs at 3× (1170×2532). The video itself (phone frame, camera, copy, score) is built outside the
repo, in `~/Desktop/winklo-playstore/app-promo/`.

## Run

```sh
export PROMO_DIR=~/Desktop/winklo-playstore/app-promo          # fonts/ and net/ in, capture/ out
export PROMO_FFMPEG=~/Desktop/winklo-playstore/zip-commercial/node_modules/ffmpeg-static/ffmpeg
flutter test tool/promo_capture/promo_capture_test.dart                       # all shots, ~15 min
flutter test tool/promo_capture/promo_capture_test.dart --plain-name zip      # one shot
```

`PROMO_DIR` needs:

- `fonts/Lexend-300.ttf` … `Lexend-900.ttf`: the static weights from Google Fonts. The app gets
  Lexend through google_fonts at runtime, so the repo doesn't ship it.
- `net/games/*_tile_*.png` and `net/medals/medal_*.png`: the R2 images under `static/` (see
  `StaticAssetsConfig`).

Each shot writes `capture/<shot>/00001.jpg`… and `shot.json` (its start on the grid, frame count and
every touch, for the compositor's touch ripples).

| Shot | Bars | What it plays |
|---|---|---|
| `home` | 0–1 | Home, then a tap on "Play today's Zip" |
| `zip` | 2–6 | The 8×8 run, eighths → sixteenths → thirty-seconds, a breath one cell short, the last move on bar 6 |
| `results` | 7 | The Results scoreboard for a 0:48 clear, #4 of 12 |
| `path_words` | 8–9 | Five words traced on sixteenths |
| `sudoku` | 10–11 | The last six cells, one a beat (the rest are filled off camera) |
| `leaderboard` | 12–16 | Loading through the break, the podium on bar 14, then the Path and Sudoku tabs |
| `critters` | 17–18 | Profile → avatar sheet → the tiger → back |
| `streak` | 19–20 | Home with all three cleared on a 7-day streak |

## Things that aren't obvious

- **Board text.** The Flame boards paint numbers and letters with `TextPainter`s outside the theme.
  The test engine draws its default font as boxes, and no font registration can replace that default.
  So `BoardText.family` (`lib/core/theme/board_text.dart`) names a family for them. It's null in the
  app (the phone's sans) and `Roboto` here.
- **The run clock** is a debug-only label (`DevRunTimerLabel`; release shows nothing). It also reads
  the wall clock, which runs about 20× faster than the capture's fake clock, so `hideDebugOnly` blanks
  it before every frame.
- **Network images** go through `CachedNetworkImage`, which needs sqflite. The real PNGs are put
  straight into `imageCache` under their `CachedNetworkImageProvider` keys before the app is pumped.
- **Flame widgets** are `GameWidget<ZipGame>` and so on, so find them with a predicate,
  not `find.byType(GameWidget)`.
- **Zip's level id** must look like a real daily (`daily_YYYYMMDD`), because Home keys Zip's clear
  by it (`zip_${level.id}`), while the other games are keyed by day.
- Capture runs at about 0.3 s per frame: `toImage` gives raw RGBA, which goes straight into ffmpeg's
  stdin, because PNG encoding in Dart is about 5× slower.
