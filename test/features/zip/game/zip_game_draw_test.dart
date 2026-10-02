import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const drawn = [Cell(0, 0), Cell(0, 1), Cell(1, 1)];

  ZipGame gameWithPath() {
    final game = ZipGame(
      level: ZipLevel(
        id: 'draw-test',
        size: 2,
        numbers: {const Cell(0, 0): 1, const Cell(1, 0): 2},
        walls: const [],
        solution: const [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
      ),
      onWin: () {},
      onStatsChanged: (_, _) {},
    );
    game.path.addAll(drawn);
    return game;
  }

  test('dragging over a non-adjacent earlier cell does not jump the tip', () {
    final game = gameWithPath();

    game.extendTo(const Cell(0, 0));

    expect(game.path, drawn);
  });

  test('dragging to the previous cell pops the last cell', () {
    final game = gameWithPath();

    game.extendTo(const Cell(0, 1));

    expect(game.path, const [Cell(0, 0), Cell(0, 1)]);
  });

  test('dragging back through previous cells pops LIFO', () {
    final game = gameWithPath();

    game.extendTo(const Cell(0, 1));
    game.extendTo(const Cell(0, 0));

    expect(game.path, const [Cell(0, 0)]);
  });

  test('tapping an earlier cell makes it the last drawn cell', () {
    final game = gameWithPath();

    game.truncateTo(const Cell(0, 1));

    expect(game.path, const [Cell(0, 0), Cell(0, 1)]);
  });

  test('tapping the current tip leaves the path unchanged', () {
    final game = gameWithPath();

    game.truncateTo(const Cell(1, 1));

    expect(game.path, drawn);
  });

  test('pressing an earlier path cell rewinds the tip and starts a stroke', () {
    final game = gameWithPath();

    expect(game.beginStrokeAt(const Cell(0, 0)), isTrue);

    expect(game.path, const [Cell(0, 0)]);
  });

  test('after press rewind, extend continues from the new tip', () {
    final game = gameWithPath();

    expect(game.beginStrokeAt(const Cell(0, 0)), isTrue);
    game.extendTo(const Cell(1, 0));

    expect(game.path, const [Cell(0, 0), Cell(1, 0)]);
  });

  test('press rewind then extend leaves tip ready for a new branch', () {
    final game = gameWithPath();

    // Simulates pointer-down on an earlier path cell, then drag into empty.
    expect(game.beginStrokeAt(const Cell(0, 1)), isTrue);
    expect(game.path, const [Cell(0, 0), Cell(0, 1)]);
    game.extendTo(const Cell(1, 1));

    expect(game.path, const [Cell(0, 0), Cell(0, 1), Cell(1, 1)]);
  });
}
