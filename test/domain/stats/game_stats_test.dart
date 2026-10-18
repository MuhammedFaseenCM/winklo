import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/stats/game_stats.dart';

GameDayRecord _clear(
  String playId,
  int time, {
  String gameId = GameIds.zip,
  bool usedHints = false,
}) => GameDayRecord(
  gameId: gameId,
  playId: playId,
  timeSeconds: time,
  usedHints: usedHints,
  hadMistakes: false,
  flagsKnown: true,
);

void main() {
  final today = DateTime(2026, 10, 15);

  test('no clears', () {
    final stats = computeGameStats(
      gameId: GameIds.zip,
      days: const [],
      streak: const GameStreak(gameId: GameIds.zip),
      today: today,
    );
    expect(stats.clears, 0);
    expect(stats.currentStreak, 0);
    expect(stats.longestStreak, 0);
    expect(stats.bestSeconds, isNull);
    expect(stats.averageSeconds, isNull);
    expect(stats.hintFreeShare, isNull);
    expect(stats.histogram, isEmpty);
    expect(stats.calendar, isEmpty);
    expect(stats.trend, isEmpty);
  });

  test('counts, best, rounded average and hint-free share', () {
    final stats = computeGameStats(
      gameId: GameIds.zip,
      days: [
        _clear('20261001', 60),
        _clear('20261002', 45, usedHints: true),
        _clear('20261005', 50),
        // Not cleared: ignored.
        const GameDayRecord(
          gameId: GameIds.zip,
          playId: '20261006',
          hintsUsed: 1,
        ),
      ],
      streak: const GameStreak(gameId: GameIds.zip),
      today: today,
    );
    expect(stats.clears, 3);
    expect(stats.bestSeconds, 45);
    expect(stats.averageSeconds, 52); // 155 / 3 = 51.67
    expect(stats.hintFreeShare, closeTo(2 / 3, 1e-9));
    expect(stats.histogram.fold<int>(0, (s, b) => s + b.count), 3);
    expect(stats.calendar.single.clearedDays, {1, 2, 5});
    expect(stats.trend, hasLength(30));
  });

  test('the current streak comes from the stored streak', () {
    final stats = computeGameStats(
      gameId: GameIds.zip,
      days: [_clear('20261014', 60), _clear('20261015', 60)],
      streak: const GameStreak(
        gameId: GameIds.zip,
        current: 5,
        longest: 5,
        lastClearedDateId: '20261015',
      ),
      today: today,
    );
    expect(stats.currentStreak, 5);
    expect(stats.longestStreak, 5);
  });

  test('the longest streak is the max of the stored one and day runs', () {
    final stats = computeGameStats(
      gameId: GameIds.zip,
      days: [
        _clear('20260929', 60),
        _clear('20260930', 60),
        _clear('20261001', 60),
        _clear('20261003', 60),
      ],
      streak: const GameStreak(gameId: GameIds.zip, current: 1, longest: 2),
      today: today,
    );
    expect(stats.longestStreak, 3);
  });

  test('ignores other games and collapses debug periods by date', () {
    final stats = computeGameStats(
      gameId: GameIds.zip,
      days: [
        _clear('202610150900', 80),
        _clear('202610151000', 70),
        _clear('20261015', 30, gameId: GameIds.sudoku),
      ],
      streak: const GameStreak(gameId: GameIds.zip),
      today: today,
    );
    expect(stats.clears, 2);
    expect(stats.bestSeconds, 70);
    expect(stats.calendar.single.clearedDays, {15});
    expect(stats.trend.last.seconds, 70);
  });
}
