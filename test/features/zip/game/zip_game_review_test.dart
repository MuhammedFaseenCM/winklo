import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';

void main() {
  // 3x3 corner to corner: the row snake and the column snake both win.
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
    id: 'review',
    size: 3,
    numbers: {const Cell(0, 0): 1, const Cell(2, 2): 2},
    walls: const [],
    solution: rowSnake,
  );

  Future<ZipGame> loadReview(List<Cell> initialPath) async {
    final game = ZipGame(
      level: level,
      onWin: () {},
      onStatsChanged: (_, _) {},
      readOnly: true,
      initialPath: initialPath,
    );
    game.onGameResize(Vector2.all(300));
    await game.onLoad();
    return game;
  }

  test('review shows the player path, not the solution', () async {
    final game = await loadReview(columnSnake);

    expect(game.path, columnSnake);
  });

  test('review falls back to the solution without a saved path', () async {
    final game = await loadReview(const []);

    expect(game.path, rowSnake);
  });

  test(
    'review falls back to the solution for a path that does not win',
    () async {
      final game = await loadReview(const [Cell(0, 0), Cell(0, 1)]);

      expect(game.path, rowSnake);
    },
  );
}
