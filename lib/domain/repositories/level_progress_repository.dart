import '../entities/level_progress.dart';

/// What a cleared level run did to the level's record.
class LevelClearResult {
  const LevelClearResult({
    required this.runStars,
    required this.current,
    this.previous,
  });

  /// Stars this run earned on its own.
  final int runStars;

  /// The record before this run; null on a first clear.
  final LevelRecord? previous;

  /// The record after this run.
  final LevelRecord current;

  bool get firstClear => previous == null;
  bool get moreStars => previous != null && current.stars > previous!.stars;
  bool get fasterTime =>
      previous != null && current.bestSeconds < previous!.bestSeconds;

  /// A replay beat the record (a first clear has nothing to beat).
  bool get improved => moreStars || fasterTime;
}

/// The signed-in player's level progress on this device.
///
/// Read synchronously by the UI. Kept per account, so signing into another
/// account shows that account's map.
abstract class LevelProgressRepository {
  /// Fires after any write, including [restore].
  Stream<void> get changes;

  LevelProgress progress(String game);

  /// Keeps a cleared run of [levelId]; the record only ever improves.
  Future<LevelClearResult> record(
    String game,
    String levelId, {
    required int stars,
    required int seconds,
  });

  /// Replaces the progress with [merged] after a sync, without asking for
  /// another sync.
  Future<void> restore(String game, LevelProgress merged);

  /// Whether the progress differs from what was last pushed.
  bool needsPush(String game);

  Future<void> markPushed(String game, LevelProgress pushed);
}

/// The account's copy, `users/{uid}/level_progress/{game}`.
abstract class LevelProgressRemoteRepository {
  /// The doc's raw `levels` map, or null when there is no doc.
  Future<Object?> fetch(String uid, String game);

  Future<void> save(String uid, String game, LevelProgress progress);
}
