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

  /// Every stored day of the daily games for [uid] (malformed docs skipped).
  /// With [fromServer] the read never falls back to the offline cache, so
  /// it throws while offline. Throws when the remote copy can't be read.
  Future<List<GameDayRecord>> fetchAllDays({
    required String uid,
    bool fromServer = false,
  });

  /// Writes [records] (at most [maxDayBatch]) as one batch of merge writes.
  /// When the rules reject the batch, each record is written on its own and
  /// the rejected ones are skipped; returns how many were skipped. Throws on
  /// any other failure (offline, timeout), so the caller can retry.
  Future<int> saveDayBatch({
    required String uid,
    required List<GameDayRecord> records,
  });

  /// Firestore allows 500 writes per batch.
  static const maxDayBatch = 500;
}
