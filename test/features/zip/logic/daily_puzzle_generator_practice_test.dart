import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:winklo/features/zip/logic/path_validator.dart';

void main() {
  test('practice boards follow the hard dailies: 8x8, 6-7 numbers, '
      '16-20 walls', () {
    for (var seed = 0; seed < 60; seed++) {
      final level = DailyPuzzleGenerator.practice(seed: seed * 7919 + 3);
      expect(level.size, 8, reason: 'seed $seed');
      expect(level.numbers.length, inInclusiveRange(6, 7), reason: '$seed');
      expect(level.walls.length, inInclusiveRange(16, 20), reason: '$seed');
    }
  });

  test('the solution visits every cell, in order, through no wall', () {
    for (var seed = 0; seed < 60; seed++) {
      final level = DailyPuzzleGenerator.practice(seed: seed * 104729 + 11);
      final validator = PathValidator(level);
      final solution = level.solution;
      expect(solution.toSet().length, 64);
      var path = <Cell>[];
      for (final cell in solution) {
        final next = validator.tryExtend(path: path, candidate: cell);
        expect(next, isNotNull, reason: 'seed $seed blocked at $cell');
        path = next!;
      }
      expect(validator.isWon(path), isTrue, reason: 'seed $seed');
      expect(level.numbers[solution.first], 1);
      expect(level.numbers[solution.last], level.maxNumber);
    }
  });

  test('the same seed gives the same board; other seeds differ', () {
    final a = DailyPuzzleGenerator.practice(seed: 42);
    final b = DailyPuzzleGenerator.practice(seed: 42);
    final c = DailyPuzzleGenerator.practice(seed: 43);
    expect(a.fingerprint, b.fingerprint);
    expect(a.id, b.id);
    expect(a.fingerprint, isNot(c.fingerprint));
    expect(a.id, isNot(c.id));
    expect(a.id.startsWith('practice_'), isTrue);
  });
}
