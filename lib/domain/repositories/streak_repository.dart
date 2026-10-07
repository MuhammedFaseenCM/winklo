import '../entities/game_streak.dart';

abstract class StreakRepository {
  Future<GameStreak> getStreak(String gameId);

  Future<GameStreak> saveStreak(GameStreak streak);

  /// Writes a streak merged from the remote copy. Returns whether the stored
  /// streak changed. Unlike [saveStreak] it is not a local progress change, so
  /// it does not trigger a sync push.
  Future<bool> restoreStreak(GameStreak streak);
}
