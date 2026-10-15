import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';

void main() {
  const games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  group('weekStart', () {
    test('a Sunday belongs to the Monday before', () {
      expect(
        WeeklyRecap.weekStart(DateTime(2026, 10, 18, 19)),
        DateTime(2026, 10, 12),
      );
    });

    test('a Monday is its own week start', () {
      expect(
        WeeklyRecap.weekStart(DateTime(2026, 10, 12, 8)),
        DateTime(2026, 10, 12),
      );
    });

    test('crosses month ends', () {
      expect(
        WeeklyRecap.weekStart(DateTime(2026, 11, 1)),
        DateTime(2026, 10, 26),
      );
    });
  });

  WeeklyRecap build({
    Map<String, int> times = const {},
    Map<String, int> currentStreaks = const {},
    Set<String> pointsOnly = const {},
  }) {
    return WeeklyRecap.build(
      weekStart: DateTime(2026, 10, 12),
      gameIds: games,
      clearedOn: (gameId, dateId) =>
          times.containsKey('${gameId}_$dateId') ||
          pointsOnly.contains('${gameId}_$dateId'),
      timeOn: (gameId, dateId) => times['${gameId}_$dateId'],
      currentStreaks: currentStreaks,
    );
  }

  test('counts clears Monday to Sunday only', () {
    final recap = build(
      times: {
        'zip_20261011': 30, // the Sunday before
        'zip_20261012': 70,
        'zip_20261018': 65,
        'sudoku_20261014': 200,
        'zip_20261019': 20, // the Monday after
      },
      pointsOnly: {'path_words_20261013'},
    );
    expect(recap.weekStartId, '20261012');
    expect(recap.cleared, 4);
    expect(recap.possible, 21);
    expect(recap.isEmpty, isFalse);
  });

  test('best is the fastest clear of the week, with its game', () {
    final recap = build(
      times: {
        'zip_20261012': 70,
        'zip_20261013': 58,
        'path_words_20261013': 90,
        'sudoku_20261014': 200,
      },
    );
    expect(recap.bestGameId, GameIds.zip);
    expect(recap.bestSeconds, 58);
  });

  test('a tie on time goes to the earlier game', () {
    final recap = build(
      times: {'sudoku_20261012': 60, 'path_words_20261013': 60},
    );
    expect(recap.bestGameId, GameIds.pathWords);
  });

  test('a 0 s clear counts but is not a best', () {
    final recap = build(times: {'zip_20261012': 0});
    expect(recap.cleared, 1);
    expect(recap.bestSeconds, isNull);
    expect(recap.bestGameId, isNull);
  });

  test('the streak is the longest current streak of 2 days or more', () {
    final recap = build(
      times: {'zip_20261012': 70},
      currentStreaks: {GameIds.zip: 3, GameIds.sudoku: 5},
    );
    expect(recap.streakGameId, GameIds.sudoku);
    expect(recap.streakDays, 5);

    final short = build(
      times: {'zip_20261012': 70},
      currentStreaks: {GameIds.zip: 1},
    );
    expect(short.streakGameId, isNull);
    expect(short.streakDays, 0);
  });

  test('no clears is an empty recap', () {
    final recap = build(currentStreaks: {GameIds.zip: 9});
    expect(recap.cleared, 0);
    expect(recap.isEmpty, isTrue);
  });
}
