abstract final class SudokuScoring {
  static int pointsForElapsed(int elapsedSeconds) =>
      (1000 - elapsedSeconds * 5).clamp(50, 1000);
}
