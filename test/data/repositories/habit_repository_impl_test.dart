import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/habit_repository_impl.dart';
import 'package:winklo/data/repositories/progress_local_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/freeze_saved_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HabitRepositoryImpl> repoWith([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return HabitRepositoryImpl(await SharedPreferences.getInstance());
  }

  group('freeze-saved notices', () {
    test('takeFreezeSavedNotices returns them once, oldest first', () async {
      final repo = await repoWith();
      await repo.addFreezeSavedNotice(
        const FreezeSavedNotice(gameId: GameIds.zip, days: 12),
      );
      await repo.addFreezeSavedNotice(
        const FreezeSavedNotice(gameId: GameIds.sudoku, days: 5),
      );

      expect(await repo.takeFreezeSavedNotices(), const [
        FreezeSavedNotice(gameId: GameIds.zip, days: 12),
        FreezeSavedNotice(gameId: GameIds.sudoku, days: 5),
      ]);
      expect(await repo.takeFreezeSavedNotices(), isEmpty);
    });

    test('a newer notice for the same game replaces the older', () async {
      final repo = await repoWith();
      await repo.addFreezeSavedNotice(
        const FreezeSavedNotice(gameId: GameIds.zip, days: 5),
      );
      await repo.addFreezeSavedNotice(
        const FreezeSavedNotice(gameId: GameIds.zip, days: 9),
      );
      expect(await repo.takeFreezeSavedNotices(), const [
        FreezeSavedNotice(gameId: GameIds.zip, days: 9),
      ]);
    });

    test('unreadable data reads as no notices', () async {
      final repo = await repoWith({
        HabitRepositoryImpl.freezeSavedKey: 'not json',
      });
      expect(await repo.takeFreezeSavedNotices(), isEmpty);

      final odd = await repoWith({
        HabitRepositoryImpl.freezeSavedKey:
            '[{"gameId": 3}, {"gameId": "zip", "days": 4}, 7]',
      });
      expect(await odd.takeFreezeSavedNotices(), const [
        FreezeSavedNotice(gameId: GameIds.zip, days: 4),
      ]);
    });

    test('notices are per-user progress (purged on an account switch)', () {
      expect(
        userProgressKeyPrefixes.any(
          HabitRepositoryImpl.freezeSavedKey.startsWith,
        ),
        isTrue,
      );
    });
  });

  group('weekly recap dismissal', () {
    test('round-trips the dismissed week', () async {
      final repo = await repoWith();
      expect(repo.dismissedRecapWeek, isNull);
      await repo.dismissRecapWeek('20261012');
      expect(repo.dismissedRecapWeek, '20261012');
    });

    test('is per-user progress: another account starts undismissed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = HabitRepositoryImpl(prefs);
      final progress = ProgressLocalRepositoryImpl(prefs);
      await repo.dismissRecapWeek('20261012');

      await progress.stashUserProgress('a');
      await progress.purgeUserProgress();
      expect(repo.dismissedRecapWeek, isNull);

      await progress.restoreStashedProgress('a');
      expect(repo.dismissedRecapWeek, '20261012');
    });
  });
}
