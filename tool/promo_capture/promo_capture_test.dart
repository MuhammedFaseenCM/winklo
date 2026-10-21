// The promo's real-screen shots, recorded at 60 fps on the 128 BPM grid.
// Run from the repo root (see README.md):
//   PROMO_DIR=... PROMO_FFMPEG=... flutter test tool/promo_capture/promo_capture_test.dart
// One shot: add --plain-name '<shot>'.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/user_avatar.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/sudoku/sudoku_generator.dart';
import 'package:winklo/domain/usecases/next_uncleared_daily.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_game_tabs.dart';
import 'package:winklo/features/profile/view/profile_screen.dart';
import 'package:winklo/features/results/results_args.dart';

import 'promo_data.dart';
import 'promo_harness.dart';

const _games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

/// Seven straight days of all three games, ending today.
GameHistory _week(DateTime today) => GameHistory(
  days: [
    for (var d = 6; d >= 0; d--)
      for (final (i, game) in _games.indexed)
        GameDayRecord(
          gameId: game,
          playId: dayId(today.subtract(Duration(days: d))),
          timeSeconds: [48, 79, 228][i] + d * 3,
          usedHints: false,
        ),
  ],
  streaks: {
    for (final game in _games)
      game: GameStreak(
        gameId: game,
        current: 7,
        longest: 7,
        lastClearedDateId: dayId(today),
      ),
  },
  today: today,
);

/// All three dailies cleared today on a 7-day streak, as Home reads them
/// (scores key Zip by its level, `zip_daily_<day>`, the others by game).
Map<String, Object> _clearedToday(DateTime today) {
  final id = dayId(today);
  return {
    for (final (i, game) in _games.indexed) ...{
      'streak_current_$game': 7,
      'streak_longest_$game': 7,
      'streak_last_$game': id,
      'best_pts_${NextUnclearedDaily.modeKeyFor(game, id)}': [760, 610, 420][i],
      'best_time_${NextUnclearedDaily.modeKeyFor(game, id)}': [48, 79, 228][i],
    },
  };
}

SudokuPuzzle _sudoku(DateTime _) => SudokuGenerator.practice(seed: 11);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  DevFlags.useDailyPlayPeriodInTests = true;

  setUpAll(loadPromoFonts);

  final today = DateTime.now();
  PromoApp app({Map<String, Object> prefs = const {}}) =>
      PromoApp(sudoku: _sudoku, prefs: prefs, history: _week(today));

  Future<void> open(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await PromoApp.settle(tester, 12);
  }

  // Bars 0–1: Home, then a tap on "Play today's Zip" just before the run.
  testWidgets('home', (tester) async {
    await app().pump(tester);
    final play = tester.getCenter(find.text("Play today's Zip"));
    await recordShot(
      tester,
      'home',
      from: 0,
      to: T(2) + 0.3,
      touches: [Touch.tap(T(1, 3), play)],
    );
  });

  // Bars 2–6: the run, eighths → sixteenths → thirty-seconds, a breath one
  // cell short, and the last move on the drop.
  testWidgets('zip', (tester) async {
    await app().pump(tester);
    await open(tester, "Play today's Zip");
    final at = boardCells(tester, size: 8, padding: 10);
    final cells = [for (final c in zipPath) at(c.row, c.col)];

    // steps[j]: when the line moves from cell j-1 into cell j.
    final steps = <double>[
      0,
      for (var i = 0; i < 8; i++) T(2, 0, 2 * i),
      for (var i = 0; i < 32; i++) T(3, 0, i),
      for (var i = 0; i < 22; i++) T(5, 0, i / 2),
      T(6),
    ];
    final segs = cells.length - 1;
    double glide(int j) =>
        j == segs ? 0.05 : (0.8 * (steps[j + 1] - steps[j])).clamp(0, 0.11);
    Offset finger(double t) {
      if (t < steps[1]) return cells[0];
      var j = 1;
      while (j < segs && steps[j + 1] <= t) {
        j++;
      }
      final s = ((t - steps[j]) / glide(j)).clamp(0.0, 1.0);
      final e = 1 - (1 - s) * (1 - s) * (1 - s);
      return Offset.lerp(cells[j - 1], cells[j], e)!;
    }

    await recordShot(
      tester,
      'zip',
      from: T(2) - 0.3,
      to: T(7) + 0.3,
      touches: [Touch(T(2) - 0.15, T(6) + 0.2, finger)],
    );
  });

  // Bar 7: the Results scoreboard for that clear: 0:48, #4 of 12 today.
  testWidgets('results', (tester) async {
    await app().pump(tester);
    final args = ResultsArgs(
      title: 'Puzzle cleared!',
      subtitle: '',
      timeSeconds: 48,
      improved: true,
      replayDaily: true,
      currentStreak: 7,
      longestStreak: 7,
      usedHints: false,
      gameId: GameIds.zip,
      day: today,
    );
    await recordShot(
      tester,
      'results',
      from: T(7) - 0.4,
      to: T(8) + 0.3,
      cues: [
        Cue(T(7) - 0.36, () async {
          unawaited(PromoApp.router(tester).push('/results', extra: args));
        }),
      ],
    );
  });

  // Bars 8–9: five words traced on sixteenths.
  testWidgets('path_words', (tester) async {
    await app().pump(tester);
    await open(tester, "Play today's Path Words");
    final at = boardCells(tester, size: 6, padding: 10);
    final starts = [T(8, 0), T(8, 1, 2), T(8, 3), T(9, 0, 2), T(9, 2)];
    final touches = <Touch>[];
    for (final (i, (_, _, path)) in pathWordsTraces.indexed) {
      final pts = [for (final c in path) at(c.row, c.col)];
      final t0 = starts[i];
      Offset finger(double t) {
        final u = ((t - t0) / six).clamp(0.0, pts.length - 1.0);
        final j = u.floor().clamp(0, pts.length - 2);
        final s = ((u - j) / 0.8).clamp(0.0, 1.0);
        final e = 1 - (1 - s) * (1 - s) * (1 - s);
        return Offset.lerp(pts[j], pts[j + 1], e)!;
      }

      touches.add(Touch(t0 - 0.04, t0 + (pts.length - 1) * six + 0.07, finger));
    }
    await recordShot(
      tester,
      'path_words',
      from: T(8) - 0.3,
      to: T(10) + 0.3,
      touches: touches,
    );
  });

  // Bars 10–11: the last six cells of a 6×6, one a beat, then the clear.
  testWidgets('sudoku', (tester) async {
    await app().pump(tester);
    await open(tester, "Play today's Sudoku");
    final puzzle = _sudoku(today);
    final at = boardCells(tester, size: 6, padding: 8);
    Offset key(int d) =>
        tester.getCenter(find.widgetWithText(FilledButton, '$d'));
    final blanks = [
      for (var i = 0; i < 36; i++)
        if (puzzle.given[i] == 0) i,
    ];
    // Leave six blanks spread over the board for the camera.
    final last = [
      for (var k = 0; k < 6; k++) blanks[(k * (blanks.length - 1) / 5).round()],
    ];
    for (final i in blanks.where((i) => !last.contains(i))) {
      await tester.tapAt(at(i ~/ 6, i % 6));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(key(puzzle.solution[i]));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await PromoApp.settle(tester, 4);
    final touches = <Touch>[
      for (final (k, i) in last.indexed) ...[
        Touch.tap(T(10, k) - six, at(i ~/ 6, i % 6), hold: 0.07),
        Touch.tap(T(10, k, 1), key(puzzle.solution[i]), hold: 0.07),
      ],
    ];
    await recordShot(
      tester,
      'sudoku',
      from: T(10) - 0.3,
      to: T(12) + 0.3,
      touches: touches,
    );
  });

  // Bars 12–16: the Leaderboard loads through the break, the podium lands on
  // the drop, then Path Words and Sudoku on the next two bars.
  testWidgets('leaderboard', (tester) async {
    final promo = app();
    final zip = StreamController<List<LeaderboardEntry>>.broadcast();
    promo.held[GameIds.zip] = zip;
    await promo.pump(tester);
    await open(tester, 'Leaderboard');
    // The game tabs build with the board; find each pill just before its tap.
    final pills = <String, Offset>{};
    Cue findPill(double t, String label) => Cue(t, () async {
      pills[label] = tester.getCenter(
        find.descendant(
          of: find.byType(LeaderboardGameTabs),
          matching: find.text(label),
        ),
      );
    });
    final words = AppStrings.pathWordsTab, sudoku = AppStrings.sudokuTitle;
    await recordShot(
      tester,
      'leaderboard',
      from: T(12) - 0.3,
      to: T(17) + 0.3,
      cues: [
        Cue(T(14) - 0.02, () async => zip.add(promoBoard(GameIds.zip))),
        findPill(T(15) - 0.3, words),
        findPill(T(16) - 0.3, sudoku),
      ],
      touches: [
        Touch(T(15) - 0.12, T(15) - 0.03, (_) => pills[words]!),
        Touch(T(16) - 0.12, T(16) - 0.03, (_) => pills[sudoku]!),
      ],
    );
    await zip.close();
  });

  // Bars 17–18: Profile → the critter sheet → the tiger → back.
  testWidgets('critters', (tester) async {
    await app().pump(tester);
    await open(tester, 'Profile');
    final avatar = tester.getCenter(
      find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(UserAvatar),
          )
          .first,
    );
    // The sheet's tiles exist only once it's open; find the tiger then.
    Offset? tiger;
    await recordShot(
      tester,
      'critters',
      from: T(17) - 0.3,
      to: T(19) + 0.3,
      cues: [
        Cue(T(17, 2), () async {
          tiger = tester.getCenter(
            find.byKey(const ValueKey('avatar-preset-preset_09')),
          );
        }),
      ],
      touches: [
        Touch.tap(T(17, 0, 2), avatar),
        Touch(T(17, 3), T(17, 3) + 0.09, (_) => tiger!),
        Touch.tap(T(18, 2), const Offset(195, 70)),
      ],
    );
  });

  // Bars 19–20: Home with all three cleared on a 7-day streak.
  testWidgets('streak', (tester) async {
    await app(prefs: _clearedToday(today)).pump(tester);
    await recordShot(tester, 'streak', from: T(19) - 0.3, to: T(21) + 0.3);
  });
}
