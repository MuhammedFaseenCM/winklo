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

  /// Improve-only write to all-time and today's daily board for the signed-in user.
  ///
  /// [currentStreak] is always merged when provided; time / clean-run flags
  /// update only when [timeSeconds] improves the stored best.
  Future<void> submitBestTime({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
  });
}
