import '../failures.dart';
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

  /// The only shape the keypad, notes grid and hint coach can play.
  static const playableSize = 6;
  static const playableBoxRows = 2;
  static const playableBoxCols = 3;

  /// Throws [UnsupportedPuzzle] for any board this build can't finish, such
  /// as a 9×9 (the keypad stops at 6) or a 4×4 (which would accept 5 and 6).
  factory SudokuPuzzle.fromJson(Map<String, dynamic> json, {String? id}) {
    final given = (json['given'] as List).map((e) => (e as num).toInt()).toList();
    final solution =
        (json['solution'] as List).map((e) => (e as num).toInt()).toList();
    final diffStr = json['difficulty'] as String? ?? 'easy';
    final difficulty = SudokuDifficulty.values.firstWhere(
      (d) => d.name == diffStr,
      orElse: () => SudokuDifficulty.easy,
    );
    final size = (json['size'] as num?)?.toInt() ?? playableSize;
    final boxRows = (json['boxRows'] as num?)?.toInt() ?? playableBoxRows;
    final boxCols = (json['boxCols'] as num?)?.toInt() ?? playableBoxCols;
    _checkPlayable(
      size: size,
      boxRows: boxRows,
      boxCols: boxCols,
      given: given,
      solution: solution,
    );
    return SudokuPuzzle(
      id: id ?? json['id'] as String? ?? '',
      dateId: json['dateId'] as String? ?? '',
      size: size,
      boxRows: boxRows,
      boxCols: boxCols,
      given: given,
      solution: solution,
      difficulty: difficulty,
    );
  }

  static void _checkPlayable({
    required int size,
    required int boxRows,
    required int boxCols,
    required List<int> given,
    required List<int> solution,
  }) {
    if (size != playableSize ||
        boxRows != playableBoxRows ||
        boxCols != playableBoxCols) {
      throw UnsupportedPuzzle(
        'Sudoku ${size}x$size with ${boxRows}x$boxCols boxes is not playable',
      );
    }
    const cells = playableSize * playableSize;
    if (given.length != cells || solution.length != cells) {
      throw const UnsupportedPuzzle('Sudoku grids must have 36 cells');
    }
    for (var i = 0; i < cells; i++) {
      final s = solution[i];
      final g = given[i];
      if (s < 1 || s > playableSize) {
        throw UnsupportedPuzzle('Sudoku solution digit $s is out of range');
      }
      if (g != 0 && g != s) {
        throw UnsupportedPuzzle('Sudoku given at $i disagrees with solution');
      }
    }
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
