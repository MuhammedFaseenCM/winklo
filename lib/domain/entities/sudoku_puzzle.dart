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

  factory SudokuPuzzle.fromJson(Map<String, dynamic> json, {String? id}) {
    final given = (json['given'] as List).map((e) => (e as num).toInt()).toList();
    final solution =
        (json['solution'] as List).map((e) => (e as num).toInt()).toList();
    final diffStr = json['difficulty'] as String? ?? 'easy';
    final difficulty = SudokuDifficulty.values.firstWhere(
      (d) => d.name == diffStr,
      orElse: () => SudokuDifficulty.easy,
    );
    return SudokuPuzzle(
      id: id ?? json['id'] as String? ?? '',
      dateId: json['dateId'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 6,
      boxRows: (json['boxRows'] as num?)?.toInt() ?? 2,
      boxCols: (json['boxCols'] as num?)?.toInt() ?? 3,
      given: given,
      solution: solution,
      difficulty: difficulty,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dateId': dateId,
    'size': size,
    'boxRows': boxRows,
    'boxCols': boxCols,
    'difficulty': difficulty.name,
    'given': given,
    'solution': solution,
  };
}
