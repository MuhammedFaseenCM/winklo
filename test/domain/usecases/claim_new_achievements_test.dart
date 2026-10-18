import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/achievement_repository_impl.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/usecases/claim_new_achievements.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';

class _MockLoadHistory extends Mock implements LoadGameHistory {}

GameHistory _history(List<GameDayRecord> days) =>
    GameHistory(days: days, streaks: const {}, today: DateTime(2026, 10, 15));

GameDayRecord _clear(String gameId, {int time = 90}) => GameDayRecord(
  gameId: gameId,
  playId: '20261015',
  timeSeconds: time,
  usedHints: true,
  hadMistakes: false,
  flagsKnown: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLoadHistory load;
  late AchievementRepositoryImpl store;
  late ClaimNewAchievements claim;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AchievementRepositoryImpl(await SharedPreferences.getInstance());
    load = _MockLoadHistory();
    claim = ClaimNewAchievements(loadHistory: load, store: store);
  });

  void history(List<GameDayRecord> days) => when(
    () => load(refreshRemote: any(named: 'refreshRemote')),
  ).thenAnswer((_) async => _history(days));

  Future<List<String>> claimShown({Object? occasion}) async {
    final fresh = await claim.pending(occasion: occasion);
    await claim.markShown(fresh, occasion: occasion);
    return [for (final a in fresh) a.id];
  }

  test('returns new achievements in catalog order until shown', () async {
    history([_clear(GameIds.sudoku), _clear(GameIds.zip, time: 40)]);

    final expected = [
      'first_clear_zip',
      'first_clear_sudoku',
      'zip_under_minute',
    ];
    expect((await claim.pending()).map((a) => a.id), expected);
    // Not shown yet: still pending.
    expect((await claim.pending()).map((a) => a.id), expected);
    expect(await claimShown(), expected);
    expect(await claim.pending(), isEmpty);
    expect(store.seenIds(), expected.toSet());
  });

  test('only what is new since the last announcement', () async {
    history([_clear(GameIds.zip)]);
    await claimShown();

    history([
      _clear(GameIds.zip),
      _clear(GameIds.pathWords),
      _clear(GameIds.sudoku),
    ]);
    expect(await claimShown(), [
      'first_clear_path_words',
      'first_clear_sudoku',
      'perfect_day',
    ]);
  });

  test('the same occasion gets its shown list back', () async {
    history([_clear(GameIds.zip)]);
    final occasion = Object();
    expect(await claimShown(occasion: occasion), ['first_clear_zip']);

    expect((await claim.pending(occasion: occasion)).map((a) => a.id), [
      'first_clear_zip',
    ]);
    expect(await claim.pending(occasion: Object()), isEmpty);
    expect(await claim.pending(), isEmpty);
  });

  test('nothing earned yet returns nothing and stores nothing', () async {
    history(const []);
    expect(await claimShown(), isEmpty);
    expect(store.seenIds(), isEmpty);
  });
}
