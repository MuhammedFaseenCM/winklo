import '../entities/pending_level_clear.dart';

/// Level clears that couldn't be sent yet, kept per account and game.
abstract class PendingLevelClearRepository {
  List<PendingLevelClear> pending(String uid, String game);

  /// Stores [clear], replacing an existing entry for its level only when it
  /// is [PendingLevelClear.betterThan] that one.
  Future<void> keep(String uid, String game, PendingLevelClear clear);

  Future<void> drop(String uid, String game, String levelId);
}
