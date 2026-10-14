import '../repositories/score_repository.dart';

/// A game's best time over every daily puzzle on this device.
class GetBestDailyTimeSeconds {
  GetBestDailyTimeSeconds(this._repo);
  final ScoreRepository _repo;

  int? call(String gameId) => _repo.getBestDailyTimeSeconds(gameId);
}
