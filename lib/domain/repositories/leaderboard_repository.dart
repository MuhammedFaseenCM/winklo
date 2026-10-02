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
  Future<void> submitBestTime({
    required String gameId,
    required int timeSeconds,
  });
}
