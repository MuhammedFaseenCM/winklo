import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/leaderboard_limits.dart';

void main() {
  test('accepts times from the game minimum to a day', () {
    expect(leaderboardAcceptsTime(GameIds.zip, 2), isFalse);
    expect(leaderboardAcceptsTime(GameIds.zip, 3), isTrue);
    // A real 6 s clear of the 6×6 Zip daily on 2026-10-19.
    expect(leaderboardAcceptsTime(GameIds.zip, 6), isTrue);
    expect(leaderboardAcceptsTime(GameIds.sudoku, 14), isFalse);
    expect(leaderboardAcceptsTime(GameIds.pathWords, 15), isTrue);
    expect(leaderboardAcceptsTime(GameIds.zip, leaderboardMaxSeconds), isTrue);
    expect(
      leaderboardAcceptsTime(GameIds.zip, leaderboardMaxSeconds + 1),
      isFalse,
    );
  });

  test('refuses games without a board', () {
    expect(leaderboardAcceptsTime(GameIds.wordMatch, 60), isFalse);
  });

  group('leaderboardDayIsLive', () {
    const day = '2026-10-15';

    test('opens at 10:00 UTC on the day before', () {
      expect(
        leaderboardDayIsLive(day, DateTime.utc(2026, 10, 14, 9, 59, 59)),
        isFalse,
      );
      expect(leaderboardDayIsLive(day, DateTime.utc(2026, 10, 14, 10)), isTrue);
    });

    test('closes at 12:00 UTC on the day after', () {
      expect(
        leaderboardDayIsLive(day, DateTime.utc(2026, 10, 16, 11, 59, 59)),
        isTrue,
      );
      expect(
        leaderboardDayIsLive(day, DateTime.utc(2026, 10, 16, 12)),
        isFalse,
      );
    });

    test('refuses day ids that are not real days', () {
      final now = DateTime.utc(2026, 3, 1, 12);
      expect(leaderboardDayIsLive('2026-02-30', now), isFalse);
      expect(leaderboardDayIsLive('20260301', now), isFalse);
    });
  });
}
