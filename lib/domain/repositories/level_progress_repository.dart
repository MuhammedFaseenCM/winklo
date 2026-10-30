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
  /// Fires after [record], [restore] and [forget], and when the signed-in
  /// account changes.
  Stream<void> get changes;

  /// The progress of the signed-in account in [game]; empty when none.
  LevelProgress progress(String game);

  /// Keeps a cleared run of [levelId]; the record only ever improves.
  /// [stars] is 1 to 3.
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

  /// Remembers [pushed] as the copy the account now holds.
  Future<void> markPushed(String game, LevelProgress pushed);

  /// Drops this device's copy of [uid]'s level progress (all games), after
  /// the account is deleted.
  Future<void> forget(String uid);
}
