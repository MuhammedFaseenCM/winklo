import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/levels_intro_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';

void main() {
  late SharedPreferences prefs;
  late LevelsIntroRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LevelsIntroRepositoryImpl(prefs);
  });

  test('everything starts unseen, with no last game', () {
    expect(repo.introSeen, isFalse);
    expect(repo.firstClearTipSeen, isFalse);
    expect(repo.levelsTabSeen, isFalse);
    expect(repo.lastGame, isNull);
  });

  test('each flag is kept once marked, across instances', () async {
    await repo.markIntroSeen();
    await repo.markFirstClearTipSeen();
    await repo.markLevelsTabSeen();
    final again = LevelsIntroRepositoryImpl(prefs);
    expect(again.introSeen, isTrue);
    expect(again.firstClearTipSeen, isTrue);
    expect(again.levelsTabSeen, isTrue);
  });

  test('the last game is kept for a game with Levels only', () async {
    await repo.setLastGame(GameIds.pathWords);
    expect(repo.lastGame, GameIds.pathWords);
    await repo.setLastGame(GameIds.sudoku);
    expect(repo.lastGame, GameIds.pathWords);
  });

  test('a stored game without Levels reads as none', () async {
    SharedPreferences.setMockInitialValues({'levels_last_game': 'sudoku'});
    final stale = LevelsIntroRepositoryImpl(
      await SharedPreferences.getInstance(),
    );
    expect(stale.lastGame, isNull);
  });

  test('every write tells listeners', () async {
    var count = 0;
    final sub = repo.changes.listen((_) => count++);
    await repo.markLevelsTabSeen();
    await repo.markIntroSeen();
    await repo.setLastGame(GameIds.zip);
    await Future<void>.delayed(Duration.zero);
    expect(count, 3);
    await sub.cancel();
  });
}
