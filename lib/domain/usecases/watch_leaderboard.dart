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
}
