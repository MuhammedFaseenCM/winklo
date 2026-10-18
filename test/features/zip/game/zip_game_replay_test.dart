import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';

void main() {
  // 3x3 corner to corner: the column snake wins but isn't the solution.
  const rowSnake = [
    Cell(0, 0), Cell(0, 1), Cell(0, 2), //
    Cell(1, 2), Cell(1, 1), Cell(1, 0), //
    Cell(2, 0), Cell(2, 1), Cell(2, 2),
  ];
  const columnSnake = [
    Cell(0, 0), Cell(1, 0), Cell(2, 0), //
    Cell(2, 1), Cell(1, 1), Cell(0, 1), //
    Cell(0, 2), Cell(1, 2), Cell(2, 2),
  ];

  final level = ZipLevel(
    id: 'replay',
    size: 3,
    numbers: {const Cell(0, 0): 1, const Cell(2, 2): 2},
    walls: const [],
    solution: rowSnake,
  );

  Future<ZipGame> load({bool readOnly = true, List<Cell>? initialPath}) async {
    final game = ZipGame(
      level: level,
      onWin: () {},
      onStatsChanged: (_, _) {},
      readOnly: readOnly,
      initialPath: initialPath ?? (readOnly ? columnSnake : const []),
    );
    game.onGameResize(Vector2.all(300));
    await game.onLoad();
    return game;
  }

  test('replay starts again from the first cell', () async {
    final game = await load();

    expect(game.replay(columnSnake), isTrue);

    expect(game.path, [columnSnake.first]);
    expect(game.isReplaying, isTrue);
  });

  test('replay draws about 12 cells a second', () async {
    final game = await load();
    game.replay(columnSnake);

    game.update(0.5);

    expect(game.path, columnSnake.sublist(0, 7));
  });

  test('replay rests on the full path and reports the end once', () async {
    final game = await load();
    var finished = 0;
    game.replay(columnSnake, onReplayFinished: () => finished++);

    game.update(10);
    game.update(10);

    expect(game.path, columnSnake);
    expect(game.isReplaying, isFalse);
    expect(finished, 1);
  });

  test('a second replay while one is running is ignored', () async {
    final game = await load();
    var finished = 0;
    game.replay(columnSnake, onReplayFinished: () => finished++);
    game.update(0.25);

    expect(
      game.replay(columnSnake, onReplayFinished: () => finished++),
      isFalse,
    );
    game.update(10);

    expect(finished, 1);
  });

  test('replay can run again after the last one ended', () async {
    final game = await load();
    game.replay(columnSnake);
    game.update(10);

    expect(game.replay(columnSnake), isTrue);
    expect(game.path, [columnSnake.first]);
  });

  test('replay is for review only', () async {
    final game = await load(readOnly: false, initialPath: const [Cell(0, 0)]);

    expect(game.replay(columnSnake), isFalse);

    expect(game.path, const [Cell(0, 0)]);
    expect(game.isReplaying, isFalse);
  });

  test('replay of an empty path does nothing', () async {
    final game = await load();

    expect(game.replay(const []), isFalse);
    expect(game.path, columnSnake);
  });
}
