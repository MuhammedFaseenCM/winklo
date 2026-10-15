import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/features/zip/game/zip_game.dart';
import 'package:winklo/features/zip/view/widgets/zip_replay_button.dart';

void main() {
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
  );

  Future<ZipGame> reviewGame(List<Cell> savedPath) async {
    final game = ZipGame(
      level: level,
      onWin: () {},
      onStatsChanged: (_, _) {},
      readOnly: true,
      initialPath: savedPath,
    );
    game.onGameResize(Vector2.all(300));
    await game.onLoad();
    return game;
  }

  Future<void> pump(
    WidgetTester tester,
    ZipGame game,
    List<Cell> savedPath,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZipReplayButton(game: game, level: level, savedPath: savedPath),
        ),
      ),
    );
  }

  TextButton replayButton(WidgetTester tester) => tester.widget<TextButton>(
    find.ancestor(
      of: find.text(AppStrings.zipReplay),
      matching: find.byWidgetPredicate((w) => w is TextButton),
    ),
  );

  testWidgets('is hidden without a saved winning path', (tester) async {
    final game = await reviewGame(const []);

    await pump(tester, game, const []);

    expect(find.text(AppStrings.zipReplay), findsNothing);
  });

  testWidgets('replays the saved path and waits for it to end', (tester) async {
    final game = await reviewGame(columnSnake);
    await pump(tester, game, columnSnake);

    await tester.tap(find.text(AppStrings.zipReplay));
    await tester.pump();

    expect(game.isReplaying, isTrue);
    expect(game.path, [columnSnake.first]);
    expect(replayButton(tester).onPressed, isNull);

    game.update(10);
    await tester.pump();

    expect(game.path, columnSnake);
    expect(replayButton(tester).onPressed, isNotNull);
  });
}
