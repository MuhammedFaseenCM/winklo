/// Warms the device's copy of a day's daily puzzles.
abstract class DailyPuzzlePrefetchRepository {
  /// Reads the Zip, Path Words and Sudoku dailies for [dateId] (`yyyyMMdd`)
  /// so they are cached for offline play. Returns whether all three were
  /// read; a refused, offline or missing read is false. Never throws.
  Future<bool> prefetch(String dateId);
}
