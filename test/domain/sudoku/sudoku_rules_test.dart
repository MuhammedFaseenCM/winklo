import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/sudoku/sudoku_rules.dart';

void main() {
  late SudokuPuzzle puzzle;
  late List<int> grid;
  late List<Set<int>> notes;

  setUp(() {
    // Minimal valid 6x6: given has a few clues; solution is complete.
    final solution = <int>[
      1,
      2,
      3,
      4,
      5,
      6,
      4,
      5,
      6,
      1,
      2,
      3,
      2,
      3,
      1,
      5,
      6,
      4,
      5,
      6,
      4,
      2,
      3,
      1,
      3,
      1,
      2,
      6,
      4,
      5,
      6,
      4,
      5,
      3,
      1,
      2,
    ];
    final given = List<int>.from(solution);
    given[1] = 0; // row0 col1 empty
    given[7] = 0; // row1 col1 empty
    puzzle = SudokuPuzzle(
      id: 'daily_20260927',
      dateId: '20260927',
      given: given,
      solution: solution,
      difficulty: SudokuDifficulty.easy,
    );
    grid = SudokuRules.initialGrid(puzzle);
    notes = SudokuRules.emptyNotes(puzzle.cellCount);
  });

  test('isGiven is true only for non-zero clues', () {
    expect(SudokuRules.isGiven(puzzle, 0), isTrue);
    expect(SudokuRules.isGiven(puzzle, 1), isFalse);
  });

  test('tryPlaceDigit accepts correct digit and clears notes', () {
    notes[1] = {2, 3};
    final result = SudokuRules.tryPlaceDigit(
      puzzle: puzzle,
      grid: grid,
      notes: notes,
      index: 1,
      digit: 2,
    );
    expect(result.accepted, isTrue);
    expect(result.grid[1], 2);
    expect(result.notes[1], isEmpty);
    expect(result.rejectIndex, isNull);
  });

  test('tryPlaceDigit rejects wrong digit without changing grid', () {
    final result = SudokuRules.tryPlaceDigit(
      puzzle: puzzle,
      grid: grid,
      notes: notes,
      index: 1,
      digit: 3,
    );
    expect(result.accepted, isFalse);
    expect(result.grid[1], 0);
    expect(result.rejectIndex, 1);
  });

  test('tryPlaceDigit rejects given cells', () {
    final result = SudokuRules.tryPlaceDigit(
      puzzle: puzzle,
      grid: grid,
      notes: notes,
      index: 0,
      digit: 1,
    );
    expect(result.accepted, isFalse);
  });

  test('toggleNote adds and removes candidates', () {
    final added = SudokuRules.toggleNote(
      puzzle: puzzle,
      grid: grid,
      notes: notes,
      index: 1,
      digit: 3,
    );
    expect(added.notes[1], {3});

    final removed = SudokuRules.toggleNote(
      puzzle: puzzle,
      grid: added.grid,
      notes: added.notes,
      index: 1,
      digit: 3,
    );
    expect(removed.notes[1], isEmpty);
  });

  test('eraseCell clears player digit and notes', () {
    final placed = SudokuRules.tryPlaceDigit(
      puzzle: puzzle,
      grid: grid,
      notes: notes,
      index: 1,
      digit: 2,
    );
    final erased = SudokuRules.eraseCell(
      puzzle: puzzle,
      grid: placed.grid,
      notes: placed.notes,
      index: 1,
    );
    expect(erased.grid[1], 0);
    expect(erased.notes[1], isEmpty);
  });

  test('isSolved is true only when grid matches solution', () {
    expect(SudokuRules.isSolved(grid, puzzle.solution), isFalse);
    final filled = List<int>.from(puzzle.solution);
    expect(SudokuRules.isSolved(filled, puzzle.solution), isTrue);
  });

  test('newlyCompletedUnits flashes one preferred unit but marks all', () {
    final before = List<int>.from(puzzle.solution);
    before[5] = 0; // last cell of row 0 empty
    final after = List<int>.from(before)..[5] = puzzle.solution[5];
    final result = SudokuRules.newlyCompletedUnits(
      puzzle: puzzle,
      before: before,
      after: after,
    );
    // Mark every completed unit; flash cells for preferred box only.
    expect(result.unitIds, containsAll(<String>{'b0_1', 'r0', 'c5'}));
    // Preferred flash is the top-right 2×3 box (band 0, stack 1): cols 3–5.
    expect(result.cells, equals({3, 4, 5, 9, 10, 11}));
  });

  test('newlyCompletedUnits skips already celebrated units', () {
    final before = List<int>.from(puzzle.solution);
    before[5] = 0;
    final after = List<int>.from(before)..[5] = puzzle.solution[5];
    final first = SudokuRules.newlyCompletedUnits(
      puzzle: puzzle,
      before: before,
      after: after,
    );
    final second = SudokuRules.newlyCompletedUnits(
      puzzle: puzzle,
      before: before,
      after: after,
      alreadyCelebrated: first.unitIds,
    );
    expect(second.unitIds, isEmpty);
    expect(second.cells, isEmpty);
  });

  test('newlyCompletedUnits is empty when unit was already complete', () {
    final before = List<int>.from(puzzle.solution);
    final after = List<int>.from(puzzle.solution);
    expect(
      SudokuRules.newlyCompletedUnits(
        puzzle: puzzle,
        before: before,
        after: after,
      ).cells,
      isEmpty,
    );
  });
}
