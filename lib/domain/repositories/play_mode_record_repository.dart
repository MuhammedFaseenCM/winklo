/// A run's result against the local best of its mode.
class LocalBest {
  const LocalBest({required this.best, this.previous, this.improved = false});

  /// The best after this run.
  final int best;

  /// The best before this run; null for the first clear.
  final int? previous;

  /// Whether this run beat an earlier best (a first clear has none to beat).
  final bool improved;
}

/// Bests and hint counts of the runs off the dailies: archive and practice
/// runs and the bonus games.
///
/// Kept on this device only. Nothing here reaches the streaks, the
/// leaderboards, the stats or the progress sync, and writing never fires
/// `ProgressChangeSignal`. Record keys put the mode first
/// (`archive_zip_20261009`, `practice_sudoku`, `bonus_word_match_<deck>`);
/// any other key is refused, so a daily best can't be written here.
abstract class PlayModeRecordRepository {
  /// Fires after a best is stored, so lists showing bests (the archive
  /// calendar, the Word Match decks) can refresh while a run's Results
  /// replaced the game page.
  Stream<void> get changes;

  int? bestTimeSeconds(String recordKey);

  /// Keeps the lower of [timeSeconds] and the stored best.
  Future<LocalBest> recordTime(String recordKey, int timeSeconds);

  int? bestScore(String recordKey);

  /// Keeps the higher of [score] and the stored best.
  Future<LocalBest> recordScore(String recordKey, int score);

  /// Hints spent in the archive run [runId] (`archive_<yyyyMMdd>`) of
  /// [gameId].
  int hintsUsed(String gameId, String runId);

  Future<void> setHintsUsed(String gameId, String runId, int used);

  /// Gives [runId] a full set of hints again, when a fresh run starts.
  Future<void> clearHints(String gameId, String runId);
}
