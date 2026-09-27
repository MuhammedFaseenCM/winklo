import 'sudoku_difficulty.dart';

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.id,
    required this.dateId,
    required this.given,
    required this.solution,
    required this.difficulty,
    this.size = 6,
    this.boxRows = 2,
    this.boxCols = 3,
  });

  final String id;
  final String dateId;
  final int size;
  final int boxRows;
  final int boxCols;
  final List<int> given;
  final List<int> solution;
  final SudokuDifficulty difficulty;

  int get cellCount => size * size;

  int indexOf(int row, int col) => row * size + col;
}
