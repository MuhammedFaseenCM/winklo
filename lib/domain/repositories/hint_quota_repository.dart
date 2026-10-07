abstract class HintQuotaRepository {
  static const int cap = 3;

  int remaining(String gameId);

  /// Decrements used count for the current play period when remaining > 0.
  /// Returns remaining after the attempt (0 if already exhausted).
  Future<int> tryConsume(String gameId);

  /// Hints consumed for [gameId] in the period [playId].
  int usedFor(String gameId, String playId);

  /// Raises the used count for [gameId] / [playId] to [used] (max, never
  /// lowers). Returns whether the stored count changed.
  Future<bool> restoreUsed(String gameId, String playId, int used);
}
