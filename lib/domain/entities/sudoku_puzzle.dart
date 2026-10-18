import '../failures.dart';
import '../stable_seed.dart';
import 'daily_special.dart';
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
    this.special,
  });

  final String id;
  final String dateId;
  final int size;
  final int boxRows;
  final int boxCols;
  final List<int> given;
  final List<int> solution;
  final SudokuDifficulty difficulty;

  /// `weekend` on a weekend special (see [DailySpecial]); null otherwise.
  /// Not part of the fingerprint.
  final String? special;

  bool get isWeekendSpecial => special == DailySpecial.weekend;

  int get cellCount => size * size;

  int indexOf(int row, int col) => row * size + col;

  /// Changes whenever the board does; the doc id isn't part of it.
  String get fingerprint => boardFingerprint(
    'sudoku|$size|$boxRows|$boxCols|${given.join(',')}|${solution.join(',')}',
  );

  /// The only shape the keypad, notes grid and hint coach can play.
  static const playableSize = 6;
  static const playableBoxRows = 2;
  static const playableBoxCols = 3;

  /// Throws [UnsupportedPuzzle] for any board this build can't finish, such
  /// as a 9×9 (the keypad stops at 6) or a 4×4 (which would accept 5 and 6).
  factory SudokuPuzzle.fromJson(Map<String, dynamic> json, {String? id}) {
    final given = (json['given'] as List)
        .map((e) => (e as num).toInt())
        .toList();
    final solution = (json['solution'] as List)
        .map((e) => (e as num).toInt())
        .toList();
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
      special: readDailySpecial(json['special']),
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
    // From here the shape is fine, so anything wrong is broken data: a load
    // failure, not a reason to update the app.
    const cells = playableSize * playableSize;
    if (given.length != cells || solution.length != cells) {
      throw const DailyPuzzleUnavailable('Sudoku grids must have 36 cells');
    }
    for (var i = 0; i < cells; i++) {
      final g = given[i];
      if (g != 0 && g != solution[i]) {
        throw DailyPuzzleUnavailable('Sudoku given at $i disagrees');
      }
    }
    const all = {1, 2, 3, 4, 5, 6};
    for (var n = 0; n < playableSize; n++) {
      final boxRow = (n ~/ (playableSize ~/ playableBoxCols)) * playableBoxRows;
      final boxCol = (n % (playableSize ~/ playableBoxCols)) * playableBoxCols;
      final units = [
        {for (var c = 0; c < playableSize; c++) solution[n * playableSize + c]},
        {for (var r = 0; r < playableSize; r++) solution[r * playableSize + n]},
        {
          for (var r = 0; r < playableBoxRows; r++)
            for (var c = 0; c < playableBoxCols; c++)
              solution[(boxRow + r) * playableSize + boxCol + c],
        },
      ];
      if (units.any(
        (unit) => unit.length != all.length || !all.containsAll(unit),
      )) {
        throw const DailyPuzzleUnavailable('Sudoku solution is not valid');
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
    if (special != null) 'special': special,
  };
}
