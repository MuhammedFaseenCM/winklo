import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/logic/board_layout.dart';

LeaderboardEntry _e(
  int seconds, {
  bool? usedHints,
  bool? hadMistakes,
  int? streak,
}) => LeaderboardEntry(
  uid: 'u$seconds',
  displayName: 'P',
  timeSeconds: seconds,
  updatedAt: DateTime.utc(2026, 10, 20),
  rank: 1,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  currentStreak: streak,
);

void main() {
  group('leaderboardGapSeconds', () {
    test('seconds behind on the daily and all-time boards', () {
      for (final period in [
        LeaderboardPeriod.daily,
        LeaderboardPeriod.allTime,
      ]) {
        expect(
          leaderboardGapSeconds(entry: _e(57), ahead: _e(42), period: period),
          15,
        );
      }
    });

    test('none on the weekly board, where days rank first', () {
      expect(
        leaderboardGapSeconds(
          entry: _e(57),
          ahead: _e(42),
          period: LeaderboardPeriod.weekly,
        ),
        isNull,
      );
    });

    test('none for a tie', () {
      expect(
        leaderboardGapSeconds(
          entry: _e(42),
          ahead: _e(42),
          period: LeaderboardPeriod.daily,
        ),
        isNull,
      );
    });
  });

  group('leaderboardEntryTop', () {
    test('the podium is at the top', () {
      for (final i in [0, 1, 2]) {
        expect(
          leaderboardEntryTop(index: i, headExtent: 220, rowExtent: 52),
          0,
        );
      }
    });

    test('rows start after the head', () {
      expect(
        leaderboardEntryTop(index: 3, headExtent: 220, rowExtent: 52),
        220,
      );
      expect(
        leaderboardEntryTop(index: 13, headExtent: 220, rowExtent: 52),
        220 + 10 * 52,
      );
    });
  });

  group('leaderboardBadgesFor', () {
    test('daily: hint-free, Sudoku flawless and a 2+ day streak', () {
      expect(
        leaderboardBadgesFor(
          _e(60, usedHints: false, hadMistakes: false, streak: 2),
          period: LeaderboardPeriod.daily,
          gameId: GameIds.sudoku,
        ),
        [
          LeaderboardBadge.noHints,
          LeaderboardBadge.flawless,
          LeaderboardBadge.streak,
        ],
      );
    });

    test('flawless is Sudoku only; a 1-day streak and unknowns earn none', () {
      expect(
        leaderboardBadgesFor(
          _e(60, hadMistakes: false, streak: 1),
          period: LeaderboardPeriod.daily,
          gameId: GameIds.zip,
        ),
        isEmpty,
      );
    });

    test('only the daily board shows badges', () {
      expect(
        leaderboardBadgesFor(
          _e(60, usedHints: false, streak: 9),
          period: LeaderboardPeriod.weekly,
          gameId: GameIds.zip,
        ),
        isEmpty,
      );
    });
  });
}
