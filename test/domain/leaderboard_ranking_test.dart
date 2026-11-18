import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/leaderboard_ranking.dart';

LeaderboardEntry _entry(
  String uid,
  int time, {
  int at = 0,
  int? days,
  int? stars,
  int? levels,
}) => LeaderboardEntry(
  uid: uid,
  displayName: uid,
  timeSeconds: time,
  updatedAt: DateTime.utc(2026, 10, 15, 10, at),
  rank: 0,
  daysCleared: days,
  stars: stars,
  levelsCleared: levels,
);

void main() {
  test('daily: time ascending, earlier updatedAt first, dense ranks', () {
    final ranked = rankLeaderboardEntries([
      _entry('c', 50),
      _entry('b', 40, at: 5),
      _entry('a', 40, at: 1),
      _entry('d', 70),
    ], LeaderboardPeriod.daily);
    expect(ranked.map((e) => e.uid), ['a', 'b', 'c', 'd']);
    expect(ranked.map((e) => e.rank), [1, 1, 2, 3]);
  });

  test('weekly: days descending, then total, then updatedAt', () {
    final ranked = rankLeaderboardEntries([
      _entry('slow5', 600, days: 5),
      _entry('fast3', 100, days: 3),
      _entry('fast5', 372, days: 5, at: 9),
      _entry('tie5', 372, days: 5, at: 2),
    ], LeaderboardPeriod.weekly);
    expect(ranked.map((e) => e.uid), ['tie5', 'fast5', 'slow5', 'fast3']);
    expect(ranked.map((e) => e.rank), [1, 1, 2, 3]);
  });

  test('weekly: the same total on different days is not a tie', () {
    final ranked = rankLeaderboardEntries([
      _entry('a', 100, days: 2),
      _entry('b', 100, days: 1),
    ], LeaderboardPeriod.weekly);
    expect(ranked.map((e) => e.rank), [1, 2]);
  });

  test('levels: stars descending, then fewer levels, then total time', () {
    final ranked = rankLeaderboardEntries([
      _entry('a', 60, stars: 9, levels: 3),
      _entry('b', 40, stars: 9, levels: 5),
      _entry('c', 99, stars: 12, levels: 6),
    ], LeaderboardPeriod.levels);
    expect(ranked.map((e) => e.uid), ['c', 'a', 'b']);
    expect(ranked.map((e) => e.rank), [1, 2, 3]);
  });

  test(
    'levels: equal stars, levels and time tie; one second apart does not',
    () {
      final ranked = rankLeaderboardEntries([
        _entry('a', 60, stars: 9, levels: 3, at: 1),
        _entry('b', 60, stars: 9, levels: 3, at: 2),
        _entry('c', 61, stars: 9, levels: 3),
      ], LeaderboardPeriod.levels);
      expect(ranked.map((e) => e.uid), ['a', 'b', 'c']);
      expect(ranked.map((e) => e.rank), [1, 1, 2]);
    },
  );

  test('recentLeaderboardDayIds lists 14 days, today first', () {
    final days = recentLeaderboardDayIds(DateTime(2026, 3, 2, 9));
    expect(days, hasLength(14));
    expect(days.take(3), ['2026-03-02', '2026-03-01', '2026-02-28']);
    expect(days.last, '2026-02-17');
  });
}
