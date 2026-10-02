import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/in_progress_run_repository_impl.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/game_ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('save and load round-trips a draft', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InProgressRunRepositoryImpl(prefs);

    final run = InProgressRun(
      gameId: GameIds.sudoku,
      playId: '20261003',
      elapsedMs: 12500,
      usedHintsThisRun: true,
      hadMistakesThisRun: false,
      board: {
        'grid': [1, 0, 3],
        'notes': [
          <int>[],
          <int>[2],
          <int>[],
        ],
        'notesMode': true,
      },
    );

    await repo.save(run);
    final loaded = await repo.load(
      gameId: GameIds.sudoku,
      playId: '20261003',
    );

    expect(loaded, isNotNull);
    expect(loaded!.gameId, GameIds.sudoku);
    expect(loaded.playId, '20261003');
    expect(loaded.elapsedMs, 12500);
    expect(loaded.usedHintsThisRun, isTrue);
    expect(loaded.hadMistakesThisRun, isFalse);
    expect(loaded.board['notesMode'], isTrue);
    expect(loaded.board['grid'], [1, 0, 3]);
  });

  test('load returns null for missing or different playId', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InProgressRunRepositoryImpl(prefs);

    await repo.save(
      InProgressRun(
        gameId: GameIds.zip,
        playId: '20261003',
        elapsedMs: 1000,
        board: {
          'path': [
            [0, 0],
          ],
        },
      ),
    );

    expect(
      await repo.load(gameId: GameIds.zip, playId: '20261004'),
      isNull,
    );
    expect(
      await repo.load(gameId: GameIds.sudoku, playId: '20261003'),
      isNull,
    );
  });

  test('clear removes draft', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InProgressRunRepositoryImpl(prefs);

    await repo.save(
      InProgressRun(
        gameId: GameIds.pathWords,
        playId: '20261003',
        elapsedMs: 500,
        board: const {},
      ),
    );
    await repo.clear(gameId: GameIds.pathWords, playId: '20261003');

    expect(
      await repo.load(gameId: GameIds.pathWords, playId: '20261003'),
      isNull,
    );
  });
}
