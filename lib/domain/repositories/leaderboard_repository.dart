import '../entities/leaderboard_entry.dart';
import '../entities/leaderboard_period.dart';

abstract class LeaderboardRepository {
  /// Live top entries for [gameId] and [period], ranked 1…n.
  /// For [LeaderboardPeriod.daily], [dayId] defaults to today's local calendar day.
  Stream<List<LeaderboardEntry>> watchBoard({
    required String gameId,
    required LeaderboardPeriod period,
    String? dayId,
  });

  /// Improve-only write to all-time and a daily board for the signed-in user.
  ///
  /// [dayId] (`yyyy-MM-dd`) picks the daily board and defaults to today's
  /// local calendar day ([leaderboardDayId]).
  ///
  /// [currentStreak] is always merged when provided; time / clean-run flags
  /// update only when [timeSeconds] improves the stored best.
  ///
  /// When [expectedUid] is given the write is refused (throws) unless that
  /// account is still the signed-in one, so a run started for one account
  /// never lands on another account's entries after a switch.
  Future<void> submitBestTime({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
    String? dayId,
    String? expectedUid,
  });
}
