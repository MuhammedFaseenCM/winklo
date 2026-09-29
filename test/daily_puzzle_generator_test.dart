import 'package:flutter_test/flutter_test.dart';

import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:winklo/features/zip/logic/path_validator.dart';

void main() {
  test('same day always yields the same puzzle', () {
    final a = DailyPuzzleGenerator.forDate(DateTime(2026, 9, 13));
    final b = DailyPuzzleGenerator.forDate(DateTime(2026, 9, 13, 23, 59));
    expect(a.id, b.id);
    expect(a.size, b.size);
    expect(a.maxNumber, b.maxNumber);
    expect(a.numbers, b.numbers);
  });

  test('same minute yields the same puzzle, next minute is new', () {
    final a = DailyPuzzleGenerator.forDate(
      DateTime(2026, 9, 20, 14, 31, 10),
      period: PlayPeriod.minute,
    );
    final b = DailyPuzzleGenerator.forDate(
      DateTime(2026, 9, 20, 14, 31, 59),
      period: PlayPeriod.minute,
    );
    final c = DailyPuzzleGenerator.forDate(
      DateTime(2026, 9, 20, 14, 32),
      period: PlayPeriod.minute,
    );
    expect(a.id, 'daily_202609201431');
    expect(a.id, b.id);
    expect(a.numbers, b.numbers);
    expect(c.id, 'daily_202609201432');
    expect(c.id, isNot(a.id));
  });

  test('different days yield different ids', () {
    final a = DailyPuzzleGenerator.forDate(DateTime(2026, 9, 13));
    final b = DailyPuzzleGenerator.forDate(DateTime(2026, 9, 14));
    expect(a.id, isNot(b.id));
  });

  test('numbers stay within industrial cap of 15', () {
    for (var day = 1; day <= 40; day++) {
      final level = DailyPuzzleGenerator.forDate(DateTime(2026, 1, day));
      expect(
        level.maxNumber,
        lessThanOrEqualTo(DailyPuzzleGenerator.maxNumbers),
      );
      expect(level.maxNumber, greaterThanOrEqualTo(2));
      expect(level.numbers.values.toSet().length, level.maxNumber);
      expect(level.numbers.values.contains(1), isTrue);
      expect(level.numbers.values.contains(level.maxNumber), isTrue);

      // Must end on last number cell.
      final end = level.numbers.entries
          .firstWhere((e) => e.value == level.maxNumber)
          .key;
      final start = level.numbers.entries.firstWhere((e) => e.value == 1).key;
      expect(start, isNot(end));

      final validator = PathValidator(level);
      expect(validator.endCell, end);
    }
  });

  test('grid sizes stay in the 6–8 band', () {
    for (var day = 1; day <= 20; day++) {
      final level = DailyPuzzleGenerator.forDate(DateTime(2026, 3, day));
      expect(level.size, anyOf(6, 7, 8));
    }
  });

  test('solution is a twisty Hamiltonian path, not a full-row serpentine', () {
    for (var day = 1; day <= 28; day++) {
      final level = DailyPuzzleGenerator.forDate(DateTime(2026, 9, day));
      final path = level.solution;
      expect(path.length, level.size * level.size, reason: 'day $day');
      expect(path.toSet().length, path.length, reason: 'day $day unique cells');

      for (var i = 1; i < path.length; i++) {
        final dr = (path[i].row - path[i - 1].row).abs();
        final dc = (path[i].col - path[i - 1].col).abs();
        expect(dr + dc, 1, reason: 'day $day step $i');
      }

      expect(
        _longestStraightRun(path),
        lessThan(level.size),
        reason: 'day $day should not sweep a full row or column',
      );
    }
  });

  test('Sept 29, 2026 provides a simple 6x6 puzzle with 6 numbers', () {
    final level = DailyPuzzleGenerator.forDate(DateTime(2026, 9, 29));
    expect(level.id, 'daily_20260929');
    expect(level.size, 6);
    expect(level.maxNumber, 6);
    expect(level.numbers.length, 6);
    expect(level.walls.length, 2);
    expect(level.solution.length, 36);
    expect(PathValidator(level).isWon(level.solution), isTrue);
  });
}

int _longestStraightRun(List<Cell> path) {
  if (path.length < 2) return path.length;
  var best = 1;
  var run = 1;
  var previousDr = path[1].row - path[0].row;
  var previousDc = path[1].col - path[0].col;
  for (var i = 1; i < path.length; i++) {
    final dr = path[i].row - path[i - 1].row;
    final dc = path[i].col - path[i - 1].col;
    if (dr == previousDr && dc == previousDc) {
      run++;
    } else {
      previousDr = dr;
      previousDc = dc;
      run = 2;
    }
    if (run > best) best = run;
  }
  return best;
}
