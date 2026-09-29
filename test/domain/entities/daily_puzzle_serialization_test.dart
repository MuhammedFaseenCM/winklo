import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/entities/wall.dart';
import 'package:winklo/domain/entities/zip_level.dart';

void main() {
  test('Cell fromJson handles lists, maps, and string keys', () {
    expect(Cell.fromJson([2, 3]), const Cell(2, 3));
    expect(Cell.fromJson({'row': 4, 'col': 5}), const Cell(4, 5));
    expect(Cell.fromJson('1,6'), const Cell(1, 6));
  });

  test('Wall fromJson handles cell list and map formats', () {
    final w1 = Wall.fromJson({
      'a': [1, 2],
      'b': [1, 3],
    });
    expect(w1.a, const Cell(1, 2));
    expect(w1.b, const Cell(1, 3));

    final w2 = Wall.fromJson({
      'a': {'row': 0, 'col': 1},
      'b': {'row': 0, 'col': 2},
    });
    expect(w2.a, const Cell(0, 1));
    expect(w2.b, const Cell(0, 2));
  });

  test('ZipLevel fromJson and toJson roundtrip', () {
    final json = {
      'id': 'daily_20260929',
      'size': 6,
      'order': 100,
      'numbers': {'5,5': 1, '5,0': 6},
      'walls': [
        {'a': [5, 0], 'b': [5, 1]}
      ],
      'solution': [
        [5, 5],
        [5, 0],
      ],
    };

    final level = ZipLevel.fromJson(json);
    expect(level.id, 'daily_20260929');
    expect(level.size, 6);
    expect(level.numbers[const Cell(5, 5)], 1);
    expect(level.walls.length, 1);
    expect(level.solution.length, 2);
    expect(level.toJson(), json);
  });

  test('PathWordsPuzzle fromJson and toJson roundtrip', () {
    final json = {
      'id': 'daily_20260929',
      'day': '2026-09-29T00:00:00.000',
      'size': 3,
      'letters': ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      'targets': [
        {
          'id': 'w1',
          'word': 'ABC',
          'start': [0, 0],
          'path': [
            [0, 0],
            [0, 1],
            [0, 2],
          ],
          'colorIndex': 0,
        },
      ],
    };

    final puzzle = PathWordsPuzzle.fromJson(json);
    expect(puzzle.id, 'daily_20260929');
    expect(puzzle.size, 3);
    expect(puzzle.letters.length, 9);
    expect(puzzle.targets.length, 1);
    expect(puzzle.targets.first.word, 'ABC');
    expect(puzzle.toJson(), json);
  });
}
