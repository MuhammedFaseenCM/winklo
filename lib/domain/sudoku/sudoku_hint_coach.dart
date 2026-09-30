import '../entities/sudoku_puzzle.dart';
import 'sudoku_rules.dart';

enum SudokuHintTechnique {
  lastRemainingRegion,
  lastRemainingRow,
  lastRemainingCol,
  nakedSingle,
}

class SudokuCoachHint {
  const SudokuCoachHint({
    required this.technique,
    required this.targetIndex,
    required this.digit,
    required this.evidenceIndices,
    required this.excludedIndices,
  });

  final SudokuHintTechnique technique;
  final int targetIndex;
  final int digit;
  final Set<int> evidenceIndices;
  final Set<int> excludedIndices;
}

abstract final class SudokuHintCoach {
  SudokuHintCoach._();

  static SudokuCoachHint? find({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    int? preferredIndex,
  }) {
    for (final index in _scanOrder(
      puzzle: puzzle,
      grid: grid,
      preferredIndex: preferredIndex,
    )) {
      final hint = _hintForCell(puzzle: puzzle, grid: grid, index: index);
      if (hint != null) return hint;
    }
    return null;
  }

  static Iterable<int> _scanOrder({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    int? preferredIndex,
  }) sync* {
    final preferred = _isScannable(puzzle, grid, preferredIndex)
        ? preferredIndex!
        : null;
    if (preferred != null) {
      yield preferred;
    }
    for (var i = 0; i < grid.length; i++) {
      if (i == preferred) continue;
      if (_isScannable(puzzle, grid, i)) yield i;
    }
  }

  static bool _isScannable(SudokuPuzzle puzzle, List<int> grid, int? index) {
    if (index == null || index < 0 || index >= grid.length) return false;
    return !SudokuRules.isGiven(puzzle, index) && grid[index] == 0;
  }

  static SudokuCoachHint? _hintForCell({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required int index,
  }) {
    final candidates = _candidatesFor(puzzle: puzzle, grid: grid, index: index);
    if (candidates.isEmpty) return null;

    final region = _lastRemainingInUnit(
      puzzle: puzzle,
      grid: grid,
      index: index,
      unitIndices: _boxIndices(puzzle, index),
      technique: SudokuHintTechnique.lastRemainingRegion,
    );
    if (region != null) return region;

    final row = _lastRemainingInUnit(
      puzzle: puzzle,
      grid: grid,
      index: index,
      unitIndices: _rowIndices(puzzle, index),
      technique: SudokuHintTechnique.lastRemainingRow,
    );
    if (row != null) return row;

    final col = _lastRemainingInUnit(
      puzzle: puzzle,
      grid: grid,
      index: index,
      unitIndices: _colIndices(puzzle, index),
      technique: SudokuHintTechnique.lastRemainingCol,
    );
    if (col != null) return col;

    if (candidates.length == 1) {
      final digit = candidates.first;
      return SudokuCoachHint(
        technique: SudokuHintTechnique.nakedSingle,
        targetIndex: index,
        digit: digit,
        evidenceIndices: _peerEvidenceForNakedSingle(
          puzzle: puzzle,
          grid: grid,
          index: index,
          digit: digit,
        ),
        excludedIndices: const <int>{},
      );
    }

    return null;
  }

  static SudokuCoachHint? _lastRemainingInUnit({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required int index,
    required List<int> unitIndices,
    required SudokuHintTechnique technique,
  }) {
    final candidates = _candidatesFor(puzzle: puzzle, grid: grid, index: index);
    for (final digit in candidates) {
      final holders = <int>[];
      for (final cell in unitIndices) {
        if (grid[cell] != 0) continue;
        if (_candidatesFor(
          puzzle: puzzle,
          grid: grid,
          index: cell,
        ).contains(digit)) {
          holders.add(cell);
        }
      }
      if (holders.length == 1 && holders.single == index) {
        final excluded = <int>{};
        final evidence = <int>{};
        for (final cell in unitIndices) {
          if (cell == index) continue;
          if (grid[cell] != 0) {
            excluded.add(cell);
            continue;
          }
          if (!_candidatesFor(
            puzzle: puzzle,
            grid: grid,
            index: cell,
          ).contains(digit)) {
            excluded.add(cell);
            evidence.addAll(
              _blockersForDigit(
                puzzle: puzzle,
                grid: grid,
                index: cell,
                digit: digit,
              ),
            );
          }
        }
        return SudokuCoachHint(
          technique: technique,
          targetIndex: index,
          digit: digit,
          evidenceIndices: evidence,
          excludedIndices: excluded,
        );
      }
    }
    return null;
  }

  static Set<int> _blockersForDigit({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required int index,
    required int digit,
  }) {
    final blockers = <int>{};
    for (final peer in _peerIndices(puzzle, index)) {
      if (grid[peer] == digit) blockers.add(peer);
    }
    return blockers;
  }

  static Set<int> _peerEvidenceForNakedSingle({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required int index,
    required int digit,
  }) {
    final evidence = <int>{};
    for (final peer in _peerIndices(puzzle, index)) {
      final value = grid[peer];
      if (value != 0 && value != digit) {
        evidence.add(peer);
      }
    }
    return evidence;
  }

  static Set<int> _candidatesFor({
    required SudokuPuzzle puzzle,
    required List<int> grid,
    required int index,
  }) {
    final used = <int>{};
    for (final peer in _peerIndices(puzzle, index)) {
      final value = grid[peer];
      if (value != 0) used.add(value);
    }
    return {
      for (var d = SudokuRules.digitMin; d <= SudokuRules.digitMax; d++)
        if (!used.contains(d)) d,
    };
  }

  static List<int> _rowIndices(SudokuPuzzle puzzle, int index) {
    final size = puzzle.size;
    final row = index ~/ size;
    return List<int>.generate(size, (col) => row * size + col);
  }

  static List<int> _colIndices(SudokuPuzzle puzzle, int index) {
    final size = puzzle.size;
    final col = index % size;
    return List<int>.generate(size, (row) => row * size + col);
  }

  static List<int> _boxIndices(SudokuPuzzle puzzle, int index) {
    final size = puzzle.size;
    final boxRows = puzzle.boxRows;
    final boxCols = puzzle.boxCols;
    final row = index ~/ size;
    final col = index % size;
    final band = row ~/ boxRows;
    final stack = col ~/ boxCols;
    final startRow = band * boxRows;
    final startCol = stack * boxCols;
    final indices = <int>[];
    for (var r = startRow; r < startRow + boxRows; r++) {
      for (var c = startCol; c < startCol + boxCols; c++) {
        indices.add(r * size + c);
      }
    }
    return indices;
  }

  static Iterable<int> _peerIndices(SudokuPuzzle puzzle, int index) sync* {
    final seen = <int>{index};
    for (final i in _rowIndices(puzzle, index)) {
      if (seen.add(i)) yield i;
    }
    for (final i in _colIndices(puzzle, index)) {
      if (seen.add(i)) yield i;
    }
    for (final i in _boxIndices(puzzle, index)) {
      if (seen.add(i)) yield i;
    }
  }
}
