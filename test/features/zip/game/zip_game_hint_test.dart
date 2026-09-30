import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ZipGame gameWith({List<Cell> path = const [], bool readOnly = false}) {
    final game = ZipGame(
      level: ZipLevel(
        id: 'hint-test',
        size: 2,
        numbers: {const Cell(0, 0): 1, const Cell(1, 0): 2},
        walls: const [],
        solution: const [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
      ),
      onWin: (_, _) {},
      onStatsChanged: (_, _) {},
      readOnly: readOnly,
    );
    game.path.addAll(path);
    return game;
  }

  test('first hint skips 1 and flashes the next cell', () {
    final game = gameWith();

    expect(game.hint(), isTrue);
    expect(game.hintsRemaining, 2);
    expect(game.hintedCells, const [Cell(0, 1)]);
  });

  test('later hints keep connected cells after the start', () {
    final game = gameWith();

    expect(game.hint(), isTrue);
    expect(game.hint(), isTrue);
    expect(game.hintedCells, const [Cell(0, 1), Cell(1, 1)]);
  });

  test('a spent hint does not slide ahead as the path is drawn', () {
    final game = gameWith();
    expect(game.hint(), isTrue);
    expect(game.hintedCells, const [Cell(0, 1)]);

    game.path
      ..clear()
      ..addAll(const [Cell(0, 0), Cell(0, 1)]);

    expect(game.hintedCells, isEmpty);
  });

  test('stacked hints stay on the original cells while drawing', () {
    final game = gameWith();
    expect(game.hint(), isTrue);
    expect(game.hint(), isTrue);
    expect(game.hintedCells, const [Cell(0, 1), Cell(1, 1)]);

    game.path
      ..clear()
      ..addAll(const [Cell(0, 0), Cell(0, 1)]);

    expect(game.hintedCells, const [Cell(1, 1)]);
  });

  test('reset clears the board hints', () {
    final game = gameWith();
    expect(game.hint(), isTrue);
    expect(game.hintedCells, isNotEmpty);

    game.clearPath();

    expect(game.hintedCells, isEmpty);
    expect(game.hintsRemaining, 2);
  });

  test('clearPath does not restore hintsRemaining', () {
    final game = gameWith();
    game.hintsRemaining = 1;
    game.clearPath();
    expect(game.hintsRemaining, 1);
  });

  test('hint after drawing past the spent window shows the next cell', () {
    final game = ZipGame(
      level: ZipLevel(
        id: 'hint-long',
        size: 3,
        numbers: {const Cell(0, 0): 1, const Cell(2, 2): 2},
        walls: const [],
        solution: const [
          Cell(0, 0),
          Cell(0, 1),
          Cell(0, 2),
          Cell(1, 2),
          Cell(1, 1),
          Cell(1, 0),
        ],
      ),
      onWin: (_, _) {},
      onStatsChanged: (_, _) {},
    );
    expect(game.hint(), isTrue);
    expect(game.hintedCells, const [Cell(0, 1)]);

    game.path
      ..clear()
      ..addAll(const [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 2)]);

    expect(game.hintedCells, isEmpty);
    expect(game.hint(), isTrue);
    expect(game.hintedCells, const [Cell(1, 1)]);
  });

  test('hint does nothing when the puzzle is already complete', () {
    final game = gameWith(
      path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
    );

    expect(game.canHint, isFalse);
    expect(game.hint(), isFalse);
    expect(game.hintsRemaining, 3);
  });

  test('hint does nothing in review', () {
    final game = gameWith(readOnly: true);

    expect(game.hint(), isFalse);
    expect(game.hintsRemaining, 3);
  });
}
