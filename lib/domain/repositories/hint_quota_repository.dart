abstract class HintQuotaRepository {
  static const int cap = 3;

  /// Hints left for [gameId] in the run of period [playId].
  ///
  /// Keyed by the run's period rather than the clock, so a run that crosses
  /// midnight keeps its own quota instead of getting a fresh one.
  int remaining(String gameId, String playId);

  /// Spends one hint for [gameId] in period [playId] when any are left.
  /// Returns remaining after the attempt (0 if already exhausted).
  Future<int> tryConsume(String gameId, String playId);

  /// Hints consumed for [gameId] in the period [playId].
  int usedFor(String gameId, String playId);

  /// Raises the used count for [gameId] / [playId] to [used] (max, never
  /// lowers). Returns whether the stored count changed.
  Future<bool> restoreUsed(String gameId, String playId, int used);
}
