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

  group('freeze count', () {
    Future<StreakRepositoryImpl> repoWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return StreakRepositoryImpl(await SharedPreferences.getInstance());
    }

    test('saves the count and the old bool', () async {
      final repo = await repoWith({});
      await repo.saveStreak(
        const GameStreak(
          gameId: 'zip',
          current: 14,
          longest: 14,
          lastClearedDateId: '20261014',
          freezeCount: 2,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak_freezes_zip'), 2);
      expect(prefs.getBool('streak_freeze_zip'), isTrue);
      expect((await repo.getStreak('zip')).freezeCount, 2);

      await repo.saveStreak(
        const GameStreak(gameId: 'zip', current: 1, freezeCount: 0),
      );
      expect(prefs.getInt('streak_freezes_zip'), 0);
      expect(prefs.getBool('streak_freeze_zip'), isFalse);
    });

    test('reads the old bool when the count key is missing', () async {
      final spent = await repoWith({
        'streak_current_zip': 4,
        'streak_freeze_zip': false,
      });
      expect((await spent.getStreak('zip')).freezeCount, 0);

      final kept = await repoWith({
        'streak_current_zip': 4,
        'streak_freeze_zip': true,
      });
      expect((await kept.getStreak('zip')).freezeCount, 1);

      final fresh = await repoWith({});
      expect((await fresh.getStreak('zip')).freezeCount, 1);
    });

    test('an inconsistent pair follows storedFreezeCount', () async {
      final repo = await repoWith({
        'streak_freezes_zip': 2,
        'streak_freeze_zip': false,
      });
      expect((await repo.getStreak('zip')).freezeCount, 1);
    });

    test('writes again when only the count changed', () async {
      final repo = await repoWith({});
      var calls = 0;
      final watched = StreakRepositoryImpl(
        await SharedPreferences.getInstance(),
        onChanged: () => calls++,
      );
      const base = GameStreak(
        gameId: 'zip',
        current: 7,
        longest: 7,
        lastClearedDateId: '20261014',
      );
      await watched.saveStreak(base);
      await watched.saveStreak(base.copyWith(freezeCount: 2));
      expect(calls, 2);
      expect((await repo.getStreak('zip')).freezeCount, 2);
    });

    test('a legacy streak without the count key is rewritten once', () async {
      final repo = await repoWith({
        'streak_current_zip': 3,
        'streak_longest_zip': 3,
        'streak_last_zip': '20261014',
        'streak_freeze_zip': true,
      });
      final wrote = await repo.restoreStreak(
        const GameStreak(
          gameId: 'zip',
          current: 3,
          longest: 3,
          lastClearedDateId: '20261014',
        ),
      );
      expect(wrote, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak_freezes_zip'), 1);
    });
  });
}
