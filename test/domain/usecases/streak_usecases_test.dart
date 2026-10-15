import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/habit/freeze_saved_notice.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/habit_repository.dart';
import 'package:winklo/domain/repositories/streak_repository.dart';
import 'package:winklo/domain/usecases/get_streak.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStreakRepository extends Mock implements StreakRepository {}

class _MockAnalytics extends Mock implements AnalyticsRepository {}

class _MockHabitRepository extends Mock implements HabitRepository {}

void main() {
  late _MockStreakRepository repo;

  setUp(() {
    repo = _MockStreakRepository();
    registerFallbackValue(const GameStreak(gameId: 'zip'));
  });

  test('GetStreak persists when lazy decay resets current', () async {
    when(() => repo.getStreak('zip')).thenAnswer(
      (_) async => const GameStreak(
        gameId: 'zip',
        current: 3,
        longest: 3,
        lastClearedDateId: '20260912',
        freezeAvailable: false,
      ),
    );
    when(() => repo.saveStreak(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as GameStreak,
    );

    final result = await GetStreak(repo)(
      gameId: 'zip',
      now: DateTime(2026, 9, 15),
    );

    expect(result.current, 0);
    expect(result.longest, 3);
    verify(() => repo.saveStreak(any())).called(1);
  });

  group('RecordDailyClear freeze analytics', () {
    late _MockAnalytics analytics;

    setUp(() {
      analytics = _MockAnalytics();
      when(
        () => analytics.logStreakFreezeUsed(gameId: any(named: 'gameId')),
      ).thenAnswer((_) async {});
      when(() => repo.saveStreak(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as GameStreak,
      );
    });

    test('logs streak_freeze_used when a missed day spends it', () async {
      when(() => repo.getStreak('zip')).thenAnswer(
        (_) async => const GameStreak(
          gameId: 'zip',
          current: 4,
          longest: 4,
          lastClearedDateId: '20260913',
        ),
      );

      final result = await RecordDailyClear(repo, analytics: analytics)(
        gameId: 'zip',
        dateId: '20260915',
      );

      expect(result.freezeAvailable, isFalse);
      verify(() => analytics.logStreakFreezeUsed(gameId: 'zip')).called(1);
    });

    test('logs nothing on a clear the day after', () async {
      when(() => repo.getStreak('zip')).thenAnswer(
        (_) async => const GameStreak(
          gameId: 'zip',
          current: 4,
          longest: 4,
          lastClearedDateId: '20260914',
        ),
      );

      await RecordDailyClear(repo, analytics: analytics)(
        gameId: 'zip',
        dateId: '20260915',
      );

      verifyNever(
        () => analytics.logStreakFreezeUsed(gameId: any(named: 'gameId')),
      );
    });
  });

  test('RecordDailyClear saves updated streak', () async {
    when(() => repo.getStreak('zip')).thenAnswer(
      (_) async => const GameStreak(
        gameId: 'zip',
        current: 2,
        longest: 2,
        lastClearedDateId: '20260914',
      ),
    );
    when(() => repo.saveStreak(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as GameStreak,
    );

    final result = await RecordDailyClear(repo)(
      gameId: 'zip',
      dateId: '20260915',
    );

    expect(result.current, 3);
    expect(result.lastClearedDateId, '20260915');
    verify(() => repo.saveStreak(any())).called(1);
  });

  group('RecordDailyClear freeze notices', () {
    late _MockHabitRepository habit;

    setUp(() {
      habit = _MockHabitRepository();
      registerFallbackValue(const FreezeSavedNotice(gameId: 'zip', days: 1));
      when(() => habit.addFreezeSavedNotice(any())).thenAnswer((_) async {});
      when(() => repo.saveStreak(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as GameStreak,
      );
    });

    test('a spent freeze stores a notice with the new streak', () async {
      when(() => repo.getStreak('zip')).thenAnswer(
        (_) async => const GameStreak(
          gameId: 'zip',
          current: 11,
          longest: 11,
          lastClearedDateId: '20260913',
        ),
      );

      final result = await RecordDailyClear(repo, habit: habit)(
        gameId: 'zip',
        dateId: '20260915',
      );

      expect(result.current, 12);
      verify(
        () => habit.addFreezeSavedNotice(
          const FreezeSavedNotice(gameId: 'zip', days: 12),
        ),
      ).called(1);
    });

    test('no notice without a spend', () async {
      when(() => repo.getStreak('zip')).thenAnswer(
        (_) async => const GameStreak(
          gameId: 'zip',
          current: 3,
          longest: 3,
          lastClearedDateId: '20260914',
        ),
      );

      await RecordDailyClear(repo, habit: habit)(
        gameId: 'zip',
        dateId: '20260915',
      );

      verifyNever(() => habit.addFreezeSavedNotice(any()));
    });

    test('a failing notice store does not fail the clear', () async {
      when(
        () => habit.addFreezeSavedNotice(any()),
      ).thenThrow(StateError('disk full'));
      when(() => repo.getStreak('zip')).thenAnswer(
        (_) async => const GameStreak(
          gameId: 'zip',
          current: 4,
          longest: 4,
          lastClearedDateId: '20260913',
        ),
      );

      final result = await RecordDailyClear(repo, habit: habit)(
        gameId: 'zip',
        dateId: '20260915',
      );
      expect(result.current, 5);
      verify(() => repo.saveStreak(any())).called(1);
    });

    test('logs streak_freeze_used when the spend is re-earned', () async {
      final analytics = _MockAnalytics();
      when(
        () => analytics.logStreakFreezeUsed(gameId: any(named: 'gameId')),
      ).thenAnswer((_) async {});
      when(() => repo.getStreak('zip')).thenAnswer(
        (_) async => const GameStreak(
          gameId: 'zip',
          current: 13,
          longest: 13,
          lastClearedDateId: '20260913',
        ),
      );

      final result = await RecordDailyClear(
        repo,
        analytics: analytics,
        habit: habit,
      )(gameId: 'zip', dateId: '20260915');

      // Spent on the missed day, earned back on day 14: still one.
      expect(result.current, 14);
      expect(result.freezeCount, 1);
      verify(() => analytics.logStreakFreezeUsed(gameId: 'zip')).called(1);
    });
  });
}
