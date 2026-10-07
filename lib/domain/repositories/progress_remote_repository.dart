import '../entities/game_day_record.dart';
import '../entities/game_streak.dart';

/// Private per-user progress stored under the user's account.
abstract class ProgressRemoteRepository {
  /// Null when the user has no record for that period.
  Future<GameDayRecord?> fetchDay({
    required String uid,
    required String gameId,
    required String playId,
  });

  Future<void> saveDay({required String uid, required GameDayRecord record});

  /// Null when the user has no streak stored for [gameId].
  Future<GameStreak?> fetchStreak({
    required String uid,
    required String gameId,
  });

  Future<void> saveStreak({required String uid, required GameStreak streak});
}
