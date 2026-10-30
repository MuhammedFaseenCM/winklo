import '../entities/level_progress.dart';

/// The account's copy, `users/{uid}/level_progress/{game}`.
abstract class LevelProgressRemoteRepository {
  /// The doc's raw `levels` map, or null when there is no doc.
  ///
  /// Untyped on purpose: the sync parses it with [LevelProgress.parse] to
  /// count and drop invalid entries.
  Future<Object?> fetch(String uid, String game);

  Future<void> save(String uid, String game, LevelProgress progress);
}
