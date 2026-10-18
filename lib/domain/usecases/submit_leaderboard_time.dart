import '../entities/leaderboard_proof.dart';
import '../logic/progress_merge.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/progress_local_repository.dart';
import '../repositories/score_repository.dart';

class SubmitLeaderboardTime {
  /// With [scores] and [progress], a successful (or refused) submit of the
  /// stored best time also records the sync's leaderboard marker, so
  /// `SyncProgress` does not post the same clear again, and the run's proof
  /// is saved for the sync to send if this submit doesn't get through.
  SubmitLeaderboardTime(this._repo, {this._scores, this._progress});

  final LeaderboardRepository _repo;
  final ScoreRepository? _scores;
  final ProgressLocalRepository? _progress;

  /// [dayId] (`yyyy-MM-dd`) defaults to today's local day in the repository.
  ///
  /// [playId] is the cleared play period; the marker is written only when
  /// [timeSeconds] equals the stored best for it (a slower replay must not
  /// replace the marker of the best time).
  ///
  /// [proof] lets the leaderboard Worker check the clear. With a [playId] it
  /// is saved first (for the best time, or when the day has none yet).
  ///
  /// A [LeaderboardSubmitRefused] is rethrown after recording the marker: the
  /// refusal is final, and the sync must not send the clear again (directly,
  /// without the Worker's check).
  Future<void> call({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
    String? dayId,
    String? playId,
    LeaderboardProof? proof,
  }) async {
    if (proof != null) await _saveProof(gameId, playId, timeSeconds, proof);
    try {
      await _repo.submitBestTime(
        gameId: gameId,
        timeSeconds: timeSeconds,
        usedHints: usedHints,
        hadMistakes: hadMistakes,
        currentStreak: currentStreak,
        dayId: dayId,
        proof: proof,
      );
    } on LeaderboardSubmitRefused {
      await _markConfirmed(gameId, playId, timeSeconds);
      rethrow;
    }
    await _markConfirmed(gameId, playId, timeSeconds);
  }

  /// The proof belongs with the best time, like the clear's meta and board;
  /// a slower run's proof still proves the day, so it fills a missing one.
  Future<void> _saveProof(
    String gameId,
    String? playId,
    int timeSeconds,
    LeaderboardProof proof,
  ) async {
    final progress = _progress;
    if (playId == null || progress == null) return;
    try {
      final best = _scores?.getBestTimeSeconds(modeKeyFor(gameId, playId));
      if (best != timeSeconds && progress.clearProof(gameId, playId) != null) {
        return;
      }
      await progress.setClearProof(gameId, playId, proof);
    } catch (_) {
      // Best effort: without it the sync writes the clear directly.
    }
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
