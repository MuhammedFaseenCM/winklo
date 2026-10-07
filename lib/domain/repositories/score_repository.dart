import '../entities/clear_meta.dart';

abstract class ScoreRepository {
  int getBestPoints(String modeKey);
  int? getBestTimeSeconds(String modeKey);

  /// Clean-run flags of the run behind [getBestTimeSeconds]; null when unknown
  /// (legacy clears, untimed modes).
  ClearMeta? getClearMeta(String modeKey);

  /// Improve-only. When both [usedHints] and [hadMistakes] are given with a
  /// [timeSeconds], they are stored as [ClearMeta] if this submit sets a new
  /// best time or the best time has no meta yet.
  ///
  /// Returns whether points or time improved.
  Future<bool> submitScore({
    required String modeKey,
    required int points,
    int? timeSeconds,
    bool? usedHints,
    bool? hadMistakes,
  });

  /// Improve-only restore from another copy (e.g. remote progress): points
  /// max, time min. [meta] follows the time: it is stored when [timeSeconds]
  /// becomes the best or equals a best that has no meta yet.
  ///
  /// Returns whether anything local changed.
  Future<bool> restoreBest({
    required String modeKey,
    int? points,
    int? timeSeconds,
    ClearMeta? meta,
  });
}
