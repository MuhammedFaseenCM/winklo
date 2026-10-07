import '../repositories/leaderboard_repository.dart';

class SubmitLeaderboardTime {
  SubmitLeaderboardTime(this._repo);
  final LeaderboardRepository _repo;

  Future<void> call({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
  }) => _repo.submitBestTime(
    gameId: gameId,
    timeSeconds: timeSeconds,
    usedHints: usedHints,
    hadMistakes: hadMistakes,
    currentStreak: currentStreak,
  );
}
