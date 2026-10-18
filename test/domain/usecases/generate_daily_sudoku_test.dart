import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/usecases/generate_daily_sudoku.dart';

void main() {
  test('GenerateDailySudoku throws when firestore is null', () async {
    final usecase = GenerateDailySudoku(firestore: null);
    await expectLater(
      () => usecase(day: DateTime(2026, 9, 29)),
      throwsA(isA<DailyPuzzleUnavailable>()),
    );
  });

  test('SudokuPuzzle fromJson and toJson roundtrip', () {
    final json = {
      'id': 'daily_20260929',
      'dateId': '20260929',
      'size': 6,
      'boxRows': 2,
      'boxCols': 3,
      'difficulty': 'easy',
      'given': List.filled(36, 0),
      // fromJson checks the solution is a real 6×6 Sudoku.
      'solution': [
        1, 2, 3, 4, 5, 6, //
        4, 5, 6, 1, 2, 3,
        2, 3, 1, 5, 6, 4,
        5, 6, 4, 2, 3, 1,
        3, 1, 2, 6, 4, 5,
        6, 4, 5, 3, 1, 2,
      ],
    };

    final puzzle = SudokuPuzzle.fromJson(json);
    expect(puzzle.id, 'daily_20260929');
    expect(puzzle.dateId, '20260929');
    expect(puzzle.size, 6);
    expect(puzzle.toJson(), json);
  });
}
