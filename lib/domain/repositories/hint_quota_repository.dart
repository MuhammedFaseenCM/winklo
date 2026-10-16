/// Hints spent per game and run. There is no cap: each hint costs run time
/// instead ([HintPenalty]), so this only counts them.
abstract class HintQuotaRepository {
  /// Spends one hint for [gameId] in the run of period [playId] and returns
  /// how many that run has spent now.
  ///
  /// Keyed by the run's period rather than the clock, so a run that crosses
  /// midnight keeps counting its own hints.
  Future<int> consume(String gameId, String playId);

  /// Hints consumed for [gameId] in the period [playId].
  int usedFor(String gameId, String playId);

  /// Raises the used count for [gameId] / [playId] to [used] (max, never
  /// lowers). Returns whether the stored count changed.
  Future<bool> restoreUsed(String gameId, String playId, int used);
}
