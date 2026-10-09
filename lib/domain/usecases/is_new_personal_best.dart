import 'package:winklo/domain/repositories/score_repository.dart';

/// Whether a daily clear beats the player's best time on every earlier daily
/// of the same game.
///
/// Bests are stored per day and a daily can be cleared only once, so the
/// day's own best can't tell; and a first clear has nothing to beat, so it
/// isn't a new best.
class IsNewPersonalBest {
  IsNewPersonalBest(this._repo);
  final ScoreRepository _repo;

  bool call({
    required String gameId,
    required String playId,
    required int timeSeconds,
  }) {
    final previous = _repo.getBestDailyTimeSeconds(
      gameId,
      excludingPlayId: playId,
    );
    return previous != null && timeSeconds < previous;
  }
}
