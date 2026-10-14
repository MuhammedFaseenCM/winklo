import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/entities/zip_level.dart';

const _solution = <int>[
  1, 2, 3, 4, 5, 6, //
  4, 5, 6, 1, 2, 3,
  2, 3, 1, 5, 6, 4,
  5, 6, 4, 2, 3, 1,
  3, 1, 2, 6, 4, 5,
  6, 4, 5, 3, 1, 2,
];

SudokuPuzzle _sudoku({List<int>? given, String id = 'daily_20261014'}) =>
    SudokuPuzzle(
      id: id,
      dateId: '20261014',
      given: given ?? [for (final d in _solution) d.isEven ? d : 0],
      solution: _solution,
      difficulty: SudokuDifficulty.hard,
    );

ZipLevel _zip({
  Map<Cell, int>? numbers,
  List<Wall> walls = const [],
  String id = 'daily_20261014',
}) => ZipLevel(
  id: id,
  size: 3,
  numbers: numbers ?? {const Cell(0, 0): 1, const Cell(2, 2): 2},
  walls: walls,
);

PathWordsPuzzle _pathWords({String firstLetter = 'c'}) => PathWordsPuzzle(
  id: 'daily_20261014',
  day: DateTime(2026, 10, 14),
  size: 2,
  letters: [firstLetter, 'a', 't', ''],
  targets: const [
    PathWordsTarget(
      id: 't0',
      word: 'cat',
      start: Cell(0, 0),
      path: [Cell(0, 0), Cell(0, 1), Cell(1, 0)],
      colorIndex: 0,
    ),
  ],
);

void main() {
  group('puzzle fingerprints', () {
    test('Sudoku: the same board gives the same fingerprint', () {
      expect(_sudoku().fingerprint, _sudoku().fingerprint);
    });

    test('Sudoku: different givens give a different fingerprint', () {
      final other = [for (final d in _solution) d.isOdd ? d : 0];
      expect(_sudoku(given: other).fingerprint, isNot(_sudoku().fingerprint));
    });

    test('Sudoku: the doc id does not change the fingerprint', () {
      expect(_sudoku(id: 'sudoku_20261014').fingerprint, _sudoku().fingerprint);
    });

    test('Zip: the order numbers arrive in does not matter', () {
      final reversed = _zip(
        numbers: {const Cell(2, 2): 2, const Cell(0, 0): 1},
      );
      expect(reversed.fingerprint, _zip().fingerprint);
    });

    test('Zip: moving a number changes the fingerprint', () {
      final moved = _zip(numbers: {const Cell(0, 1): 1, const Cell(2, 2): 2});
      expect(moved.fingerprint, isNot(_zip().fingerprint));
    });

    test('Zip: adding a wall changes the fingerprint', () {
      final walled = _zip(walls: const [Wall(Cell(0, 0), Cell(0, 1))]);
      expect(walled.fingerprint, isNot(_zip().fingerprint));
    });

    test('Path Words: changing a letter changes the fingerprint', () {
      expect(
        _pathWords(firstLetter: 'b').fingerprint,
        isNot(_pathWords().fingerprint),
      );
    });

    test('Path Words: the same board gives the same fingerprint', () {
      expect(_pathWords().fingerprint, _pathWords().fingerprint);
    });
  });

  group('InProgressRun board fingerprint', () {
    InProgressRun run({String? fingerprint}) => InProgressRun(
      gameId: 'sudoku',
      playId: '20261014',
      elapsedMs: 5000,
      board: const {'grid': <int>[]},
      boardFingerprint: fingerprint,
    );

    test('round-trips through JSON', () {
      final restored = InProgressRun.fromJson(run(fingerprint: 'abc').toJson());
      expect(restored.boardFingerprint, 'abc');
    });

    test('a run saved before fingerprints has none', () {
      final json = run().toJson()..remove('boardFingerprint');
      expect(InProgressRun.fromJson(json).boardFingerprint, isNull);
    });

    test('belongs to the board with the same fingerprint', () {
      expect(run(fingerprint: 'abc').isForBoard('abc'), isTrue);
    });

    test('does not belong to a replaced board', () {
      expect(run(fingerprint: 'abc').isForBoard('xyz'), isFalse);
    });

    test('a run without a fingerprint is kept, since it predates them', () {
      expect(run().isForBoard('xyz'), isTrue);
    });
  });
}
