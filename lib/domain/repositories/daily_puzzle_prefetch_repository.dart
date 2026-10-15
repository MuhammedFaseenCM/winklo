/// Warms the device's copy of a day's daily puzzles.
abstract class DailyPuzzlePrefetchRepository {
  /// Reads the Zip, Path Words and Sudoku dailies for [dateId] (`yyyyMMdd`)
  /// so they are cached for offline play. Never throws.
  Future<void> prefetch(String dateId);
}
