import 'package:winklo/data/repositories/streak_repository_impl.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round-trips streak fields per gameId', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = StreakRepositoryImpl(prefs);

    final empty = await repo.getStreak('zip');
    expect(empty.current, 0);
    expect(empty.longest, 0);
    expect(empty.lastClearedDateId, isNull);
    expect(empty.freezeAvailable, isTrue);

    await repo.saveStreak(
      const GameStreak(
        gameId: 'zip',
        current: 3,
        longest: 5,
        lastClearedDateId: '20260915',
        freezeAvailable: false,
      ),
    );

    final loaded = await repo.getStreak('zip');
    expect(loaded.current, 3);
    expect(loaded.longest, 5);
    expect(loaded.lastClearedDateId, '20260915');
    expect(loaded.freezeAvailable, isFalse);
  });

  test('isolates streaks across gameIds', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = StreakRepositoryImpl(prefs);

    await repo.saveStreak(
      const GameStreak(
        gameId: 'zip',
        current: 4,
        longest: 4,
        lastClearedDateId: '20260915',
      ),
    );
    await repo.saveStreak(
      const GameStreak(
        gameId: 'word_match',
        current: 1,
        longest: 2,
        lastClearedDateId: '20260914',
        freezeAvailable: false,
      ),
    );

    final zip = await repo.getStreak('zip');
    final match = await repo.getStreak('word_match');
    expect(zip.current, 4);
    expect(zip.freezeAvailable, isTrue);
    expect(match.current, 1);
    expect(match.longest, 2);
    expect(match.freezeAvailable, isFalse);
  });

  group('onChanged', () {
    const streak = GameStreak(
      gameId: 'zip',
      current: 2,
      longest: 3,
      lastClearedDateId: '20261007',
    );

    test('fires when saveStreak changes the stored streak', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final repo = StreakRepositoryImpl(prefs, onChanged: () => calls++);

      await repo.saveStreak(streak);
      expect(calls, 1);
      await repo.saveStreak(streak);
      expect(calls, 1, reason: 'unchanged streak is not a change');
      await repo.saveStreak(streak.copyWith(clearLastClearedDateId: true));
      expect(calls, 2);
      expect((await repo.getStreak('zip')).lastClearedDateId, isNull);
    });

    test('saving the defaults on a fresh device still persists them', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final repo = StreakRepositoryImpl(prefs, onChanged: () => calls++);

      await repo.saveStreak(const GameStreak(gameId: 'zip'));
      expect(prefs.getInt('streak_current_zip'), 0);
      expect(prefs.getBool('streak_freeze_zip'), isTrue);
      expect(calls, 1);
    });

    test('restoreStreak writes and reports changes without firing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final repo = StreakRepositoryImpl(prefs, onChanged: () => calls++);

      expect(await repo.restoreStreak(streak), isTrue);
      expect(await repo.restoreStreak(streak), isFalse);
      final loaded = await repo.getStreak('zip');
      expect(loaded.current, 2);
      expect(loaded.longest, 3);
      expect(loaded.lastClearedDateId, '20261007');
      expect(loaded.freezeAvailable, isTrue);
      expect(calls, 0);
    });
  });
}
