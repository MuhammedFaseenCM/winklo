import '../entities/sudoku_puzzle.dart';

class SudokuPlaceResult {
  const SudokuPlaceResult({
    required this.accepted,
    required this.grid,
    required this.notes,
    this.rejectIndex,
  });

  final bool accepted;
  final List<int> grid;
  final List<Set<int>> notes;
  final int? rejectIndex;
}

class SudokuHintResult {
  const SudokuHintResult({
    required this.grid,
    required this.notes,
    required this.index,
  });

  final List<int> grid;
  final List<Set<int>> notes;
  final int index;
}

abstract final class SudokuRules {
  SudokuRules._();

  static const int digitMin = 1;
  static const int digitMax = 6;

  static bool isGiven(SudokuPuzzle puzzle, int index) {
    if (index < 0 || index >= puzzle.given.length) return false;
    return puzzle.given[index] != 0;
  }

  static List<Set<int>> emptyNotes(int cellCount) =>
      List<Set<int>>.generate(cellCount, (_) => <int>{});

  static List<int> initialGrid(SudokuPuzzle puzzle) =>
      List<int>.from(puzzle.given);

  static SudokuPlaceResult tryPlaceDigit({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required List<Set<int>> notes,
    required int index,
    required int digit,
  }) {
    if (index < 0 || index >= grid.length) {
      return SudokuPlaceResult(accepted: false, grid: grid, notes: notes);
    }
    if (isGiven(puzzle, index)) {
      return SudokuPlaceResult(accepted: false, grid: grid, notes: notes);
    }
    if (digit < digitMin || digit > digitMax) {
      return SudokuPlaceResult(accepted: false, grid: grid, notes: notes);
    }
    if (puzzle.solution[index] != digit) {
      return SudokuPlaceResult(
        accepted: false,
        grid: grid,
        notes: notes,
        rejectIndex: index,
      );
    }

    final nextGrid = List<int>.from(grid);
    nextGrid[index] = digit;
    final nextNotes = notes.map(Set<int>.from).toList();
    nextNotes[index] = <int>{};
    return SudokuPlaceResult(accepted: true, grid: nextGrid, notes: nextNotes);
  }

  static ({List<int> grid, List<Set<int>> notes}) toggleNote({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required List<Set<int>> notes,
    required int index,
    required int digit,
  }) {
    if (index < 0 || index >= grid.length) {
      return (grid: grid, notes: notes);
    }
    if (isGiven(puzzle, index) || grid[index] != 0) {
      return (grid: grid, notes: notes);
    }
    if (digit < digitMin || digit > digitMax) {
      return (grid: grid, notes: notes);
    }

    final nextNotes = notes.map(Set<int>.from).toList();
    final cell = nextNotes[index];
    if (cell.contains(digit)) {
      cell.remove(digit);
    } else {
      cell.add(digit);
    }
    return (grid: grid, notes: nextNotes);
  }

  static ({List<int> grid, List<Set<int>> notes}) eraseCell({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required List<Set<int>> notes,
    required int index,
  }) {
    if (index < 0 || index >= grid.length) {
      return (grid: grid, notes: notes);
    }
    if (isGiven(puzzle, index)) {
      return (grid: grid, notes: notes);
    }
    final nextGrid = List<int>.from(grid);
    nextGrid[index] = 0;
    final nextNotes = notes.map(Set<int>.from).toList();
    nextNotes[index] = <int>{};
    return (grid: nextGrid, notes: nextNotes);
  }

  static SudokuHintResult? applyHint({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required List<Set<int>> notes,
    int? selectedIndex,
  }) {
    final index = _hintIndex(
      puzzle: puzzle,
      grid: grid,
      selectedIndex: selectedIndex,
    );
    if (index == null) return null;

    final nextGrid = List<int>.from(grid);
    nextGrid[index] = puzzle.solution[index];
    final nextNotes = notes.map(Set<int>.from).toList();
    nextNotes[index] = <int>{};
    return SudokuHintResult(grid: nextGrid, notes: nextNotes, index: index);
  }

  static bool isSolved(List<int> grid, List<int> solution) {
    if (grid.length != solution.length) return false;
    for (var i = 0; i < grid.length; i++) {
      if (grid[i] != solution[i]) return false;
    }
    return true;
  }

  /// Units (rows/cols/boxes) that became fully correct after moving from
  /// [before] to [after], excluding any ids already in [alreadyCelebrated].
  static ({Set<String> unitIds, Set<int> cells}) newlyCompletedUnits({
    required SudokuPuzzle puzzle,
    required List<int> before,
    required List<int> after,
    Set<String> alreadyCelebrated = const <String>{},
  }) {
    final size = puzzle.size;
    final boxRows = puzzle.boxRows;
    final boxCols = puzzle.boxCols;
    final solution = puzzle.solution;
    final unitIds = <String>{};
    final cells = <int>{};

    void addRow(int row) {
      final id = 'r$row';
      if (alreadyCelebrated.contains(id) || !unitIds.add(id)) return;
      for (var col = 0; col < size; col++) {
        cells.add(row * size + col);
      }
    }

    void addCol(int col) {
      final id = 'c$col';
      if (alreadyCelebrated.contains(id) || !unitIds.add(id)) return;
      for (var row = 0; row < size; row++) {
        cells.add(row * size + col);
      }
    }

    void addBox(int band, int stack) {
      final id = 'b${band}_$stack';
      if (alreadyCelebrated.contains(id) || !unitIds.add(id)) return;
      final startRow = band * boxRows;
      final startCol = stack * boxCols;
      for (var r = startRow; r < startRow + boxRows; r++) {
        for (var c = startCol; c < startCol + boxCols; c++) {
          cells.add(r * size + c);
        }
      }
    }

    for (var row = 0; row < size; row++) {
      if (!_isRowComplete(before, solution, size, row) &&
          _isRowComplete(after, solution, size, row)) {
        addRow(row);
      }
    }

    for (var col = 0; col < size; col++) {
      if (!_isColComplete(before, solution, size, col) &&
          _isColComplete(after, solution, size, col)) {
        addCol(col);
      }
    }

    final bandCount = size ~/ boxRows;
    final stackCount = size ~/ boxCols;
    for (var br = 0; br < bandCount; br++) {
      for (var bc = 0; bc < stackCount; bc++) {
        if (!_isBoxComplete(before, solution, size, boxRows, boxCols, br, bc) &&
            _isBoxComplete(after, solution, size, boxRows, boxCols, br, bc)) {
          addBox(br, bc);
        }
      }
    }

    // Flash only one unit so overlapping row/col/box don't pulse together,
    // but mark every newly completed unit celebrated so none re-animates later.
    if (unitIds.length <= 1) {
      return (unitIds: unitIds, cells: cells);
    }

    final preferred = unitIds.firstWhere(
      (id) => id.startsWith('b'),
      orElse: () => unitIds.firstWhere(
        (id) => id.startsWith('r'),
        orElse: () => unitIds.first,
      ),
    );
    final flashCells = <int>{};
    if (preferred.startsWith('r')) {
      final row = int.parse(preferred.substring(1));
      for (var col = 0; col < size; col++) {
        flashCells.add(row * size + col);
      }
    } else if (preferred.startsWith('c')) {
      final col = int.parse(preferred.substring(1));
      for (var row = 0; row < size; row++) {
        flashCells.add(row * size + col);
      }
    } else {
      final parts = preferred.substring(1).split('_');
      final band = int.parse(parts[0]);
      final stack = int.parse(parts[1]);
      final startRow = band * boxRows;
      final startCol = stack * boxCols;
      for (var r = startRow; r < startRow + boxRows; r++) {
        for (var c = startCol; c < startCol + boxCols; c++) {
          flashCells.add(r * size + c);
        }
      }
    }
    return (unitIds: unitIds, cells: flashCells);
  }

  static bool _isRowComplete(
    List<int> grid,
    List<int> solution,
    int size,
    int row,
  ) {
    for (var col = 0; col < size; col++) {
      final i = row * size + col;
      if (grid[i] == 0 || grid[i] != solution[i]) return false;
    }
    return true;
  }

  static bool _isColComplete(
    List<int> grid,
    List<int> solution,
    int size,
    int col,
  ) {
    for (var row = 0; row < size; row++) {
      final i = row * size + col;
      if (grid[i] == 0 || grid[i] != solution[i]) return false;
    }
    return true;
  }

  static bool _isBoxComplete(
    List<int> grid,
    List<int> solution,
    int size,
    int boxRows,
    int boxCols,
    int band,
    int stack,
  ) {
    final startRow = band * boxRows;
    final startCol = stack * boxCols;
    for (var r = startRow; r < startRow + boxRows; r++) {
      for (var c = startCol; c < startCol + boxCols; c++) {
        final i = r * size + c;
        if (grid[i] == 0 || grid[i] != solution[i]) return false;
      }
    }
    return true;
  }

  static int? _hintIndex({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    int? selectedIndex,
  }) {
    if (selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex < grid.length &&
        !isGiven(puzzle, selectedIndex) &&
        grid[selectedIndex] == 0) {
      return selectedIndex;
    }
    for (var i = 0; i < grid.length; i++) {
      if (!isGiven(puzzle, i) && grid[i] == 0) return i;
    }
    return null;
  }
}
