import '../repositories/leaderboard_repository.dart';

class SubmitLeaderboardTime {
  SubmitLeaderboardTime(this._repo);
  final LeaderboardRepository _repo;

  Future<void> call({required String gameId, required int timeSeconds}) =>
      _repo.submitBestTime(gameId: gameId, timeSeconds: timeSeconds);
}
