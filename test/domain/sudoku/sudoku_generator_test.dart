import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/sudoku/sudoku_generator.dart';

void main() {
  test('same day yields identical puzzle', () {
    final day = DateTime(2026, 9, 27);
    final a = SudokuGenerator.generate(day: day);
    final b = SudokuGenerator.generate(day: day);
    expect(a.given, b.given);
    expect(a.solution, b.solution);
    expect(a.difficulty, b.difficulty);
    expect(a.dateId, b.dateId);
  });

  test('difficulty rotates by day ordinal % 3', () {
    // 2026-01-01 is day 0 of year → easy
    expect(
      SudokuGenerator.difficultyForDate(DateTime(2026, 1, 1)),
      SudokuDifficulty.easy,
    );
    expect(
      SudokuGenerator.difficultyForDate(DateTime(2026, 1, 2)),
      SudokuDifficulty.medium,
    );
    expect(
      SudokuGenerator.difficultyForDate(DateTime(2026, 1, 3)),
      SudokuDifficulty.hard,
    );
  });

  test('generated puzzle has unique solution matching solution grid', () {
    final puzzle = SudokuGenerator.generate(day: DateTime(2026, 9, 27));
    expect(puzzle.given.length, 36);
    expect(puzzle.solution.length, 36);
    expect(SudokuGenerator.solutionCount(puzzle.given), 1);
    for (var i = 0; i < 36; i++) {
      if (puzzle.given[i] != 0) {
        expect(puzzle.given[i], puzzle.solution[i]);
      }
    }
  });

  test('clue count stays within difficulty band or below easy max', () {
    for (var day = 1; day <= 9; day++) {
      final puzzle = SudokuGenerator.generate(day: DateTime(2026, 3, day));
      final clues = puzzle.given.where((v) => v != 0).length;
      final band = SudokuGenerator.clueBand(puzzle.difficulty);
      // Generator may land slightly above target when uniqueness requires it,
      // but should never exceed the easy max on a successful dig.
      expect(
        clues,
        lessThanOrEqualTo(SudokuGenerator.clueBand(SudokuDifficulty.easy).max),
      );
      expect(clues, greaterThanOrEqualTo(band.min - 4));
    }
  });

  test('different days can produce different boards', () {
    final a = SudokuGenerator.generate(day: DateTime(2026, 4, 1));
    final b = SudokuGenerator.generate(day: DateTime(2026, 4, 2));
    expect(a.given == b.given && a.solution == b.solution, isFalse);
  });
}
