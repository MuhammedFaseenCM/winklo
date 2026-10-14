import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/failures.dart';

/// A valid 6×6 solution with 2×3 boxes.
const _solution6 = <int>[
  1, 2, 3, 4, 5, 6, //
  4, 5, 6, 1, 2, 3,
  2, 3, 1, 5, 6, 4,
  5, 6, 4, 2, 3, 1,
  3, 1, 2, 6, 4, 5,
  6, 4, 5, 3, 1, 2,
];

Map<String, dynamic> _json({
  Object? size = 6,
  Object? boxRows = 2,
  Object? boxCols = 3,
  List<int>? given,
  List<int>? solution,
}) {
  final sol = solution ?? _solution6;
  return {
    'dateId': '20261014',
    'size': ?size,
    'boxRows': ?boxRows,
    'boxCols': ?boxCols,
    'difficulty': 'hard',
    'given':
        given ?? [for (var i = 0; i < sol.length; i++) i.isEven ? sol[i] : 0],
    'solution': sol,
  };
}

void main() {
  group('SudokuPuzzle.fromJson', () {
    test('accepts a 6×6 board with 2×3 boxes', () {
      final puzzle = SudokuPuzzle.fromJson(_json(), id: 'daily_20261014');
      expect(puzzle.size, 6);
      expect(puzzle.cellCount, 36);
    });

    test('accepts a board with no shape fields, which default to 6×6', () {
      final puzzle = SudokuPuzzle.fromJson(
        _json(size: null, boxRows: null, boxCols: null),
      );
      expect(puzzle.size, 6);
      expect(puzzle.boxRows, 2);
      expect(puzzle.boxCols, 3);
    });

    test('rejects a 9×9 board, whose keypad would stop at 6', () {
      expect(
        () => SudokuPuzzle.fromJson(
          _json(
            size: 9,
            boxRows: 3,
            boxCols: 3,
            solution: List.filled(81, 1),
            given: List.filled(81, 0),
          ),
        ),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('rejects a 4×4 board', () {
      expect(
        () => SudokuPuzzle.fromJson(
          _json(
            size: 4,
            boxRows: 2,
            boxCols: 2,
            solution: List.filled(16, 1),
            given: List.filled(16, 0),
          ),
        ),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('rejects 3×2 boxes on a 6×6 board', () {
      expect(
        () => SudokuPuzzle.fromJson(_json(boxRows: 3, boxCols: 2)),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('rejects a solution that is not 36 cells', () {
      expect(
        () => SudokuPuzzle.fromJson(
          _json(solution: _solution6.sublist(0, 30), given: List.filled(30, 0)),
        ),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('rejects givens that are not 36 cells', () {
      expect(
        () => SudokuPuzzle.fromJson(_json(given: List.filled(35, 0))),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('rejects a solution digit outside 1–6', () {
      final solution = List<int>.from(_solution6)..[0] = 7;
      expect(
        () => SudokuPuzzle.fromJson(
          _json(solution: solution, given: List.filled(36, 0)),
        ),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('rejects a given that disagrees with the solution', () {
      final given = List.filled(36, 0)..[0] = 2; // solution says 1
      expect(
        () => SudokuPuzzle.fromJson(_json(given: given)),
        throwsA(isA<UnsupportedPuzzle>()),
      );
    });

    test('an unsupported puzzle is still a DailyPuzzleUnavailable', () {
      expect(
        () => SudokuPuzzle.fromJson(_json(boxRows: 3, boxCols: 2)),
        throwsA(isA<DailyPuzzleUnavailable>()),
      );
    });
  });
}
