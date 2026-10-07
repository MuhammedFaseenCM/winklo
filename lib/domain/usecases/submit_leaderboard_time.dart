import '../logic/progress_merge.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/progress_local_repository.dart';
import '../repositories/score_repository.dart';

class SubmitLeaderboardTime {
  /// With [scores] and [progress], a successful submit of the stored best
  /// time also records the sync's leaderboard marker, so `SyncProgress` does
  /// not post the same clear again.
  SubmitLeaderboardTime(this._repo, {this._scores, this._progress});

  final LeaderboardRepository _repo;
  final ScoreRepository? _scores;
  final ProgressLocalRepository? _progress;

  /// [dayId] (`yyyy-MM-dd`) defaults to today's local day in the repository.
  ///
  /// [playId] is the cleared play period; the marker is written only when
  /// [timeSeconds] equals the stored best for it (a slower replay must not
  /// replace the marker of the best time).
  Future<void> call({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
    String? dayId,
    String? playId,
  }) async {
    await _repo.submitBestTime(
      gameId: gameId,
      timeSeconds: timeSeconds,
      usedHints: usedHints,
      hadMistakes: hadMistakes,
      currentStreak: currentStreak,
      dayId: dayId,
    );
    await _markConfirmed(gameId, playId, timeSeconds);
  }

  Future<void> _markConfirmed(
    String gameId,
    String? playId,
    int timeSeconds,
  ) async {
    final scores = _scores;
    final progress = _progress;
    if (playId == null || scores == null || progress == null) return;
    try {
      final best = scores.getBestTimeSeconds(modeKeyFor(gameId, playId));
      if (best != timeSeconds) return;
      await progress.setPushedSignature(
        ProgressLocalRepository.leaderboardMarkerKey(gameId, playId),
        '$timeSeconds',
      );
    } catch (_) {
      // Best effort: without the marker the sync just submits once more.
    }
  }
}
