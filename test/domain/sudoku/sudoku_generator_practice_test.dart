import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/sudoku/sudoku_generator.dart';

void main() {
  test('practice boards are 6x6 hard boards with 8-9 givens and one '
      'solution, never a solved board', () {
    for (var seed = 0; seed < 120; seed++) {
      final puzzle = SudokuGenerator.practice(seed: seed * 31 + 5);
      final clues = puzzle.given.where((v) => v != 0).length;
      expect(puzzle.size, 6);
      expect(puzzle.boxRows, 2);
      expect(puzzle.boxCols, 3);
      expect(clues, inInclusiveRange(8, 9), reason: 'seed $seed');
      expect(SudokuGenerator.solutionCount(puzzle.given), 1, reason: '$seed');
      for (var i = 0; i < 36; i++) {
        if (puzzle.given[i] != 0) expect(puzzle.given[i], puzzle.solution[i]);
      }
    }
  });

  test('the app accepts a practice board as it accepts a daily', () {
    final puzzle = SudokuGenerator.practice(seed: 7);
    final parsed = SudokuPuzzle.fromJson(puzzle.toJson());
    expect(parsed.fingerprint, puzzle.fingerprint);
  });

  test('the same seed gives the same board; other seeds differ', () {
    final a = SudokuGenerator.practice(seed: 99);
    final b = SudokuGenerator.practice(seed: 99);
    final c = SudokuGenerator.practice(seed: 100);
    expect(a.fingerprint, b.fingerprint);
    expect(a.fingerprint, isNot(c.fingerprint));
    expect(a.id, 'practice_99');
  });
}
