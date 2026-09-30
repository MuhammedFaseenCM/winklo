abstract class HintQuotaRepository {
  static const int cap = 3;

  int remaining(String gameId);

  /// Decrements used count for the current play period when remaining > 0.
  /// Returns remaining after the attempt (0 if already exhausted).
  Future<int> tryConsume(String gameId);
}
