import '../entities/leaderboard_entry.dart';
import '../entities/leaderboard_period.dart';
import '../repositories/leaderboard_repository.dart';

class WatchLeaderboard {
  WatchLeaderboard(this._repo);
  final LeaderboardRepository _repo;

  Stream<List<LeaderboardEntry>> call({
    required String gameId,
    required LeaderboardPeriod period,
    String? dayId,
  }) => _repo.watchBoard(gameId: gameId, period: period, dayId: dayId);

  /// The same board for a league's [memberUids] only.
  Stream<List<LeaderboardEntry>> members({
    required String gameId,
    required LeaderboardPeriod period,
    required List<String> memberUids,
    String? dayId,
  }) => _repo.watchMembersBoard(
    gameId: gameId,
    period: period,
    memberUids: memberUids,
    dayId: dayId,
  );
}
