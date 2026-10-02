import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gameId = 'zip';

  GameStreak streak({
    int current = 0,
    int longest = 0,
    String? last,
    bool freeze = true,
  }) {
    return GameStreak(
      gameId: gameId,
      current: current,
      longest: longest,
      lastClearedDateId: last,
      freezeAvailable: freeze,
    );
  }

  group('dateId', () {
    test('formats local YYYYMMDD', () {
      expect(StreakCalculator.dateId(DateTime(2026, 9, 15)), '20260915');
      expect(StreakCalculator.dateId(DateTime(2026, 1, 5)), '20260105');
    });

    test('UTC instant uses local calendar components', () {
      final utc = DateTime.utc(2026, 9, 15, 22, 0);
      final local = utc.toLocal();
      final expected =
          '${local.year.toString().padLeft(4, '0')}'
          '${local.month.toString().padLeft(2, '0')}'
          '${local.day.toString().padLeft(2, '0')}';
      expect(StreakCalculator.dateId(utc), expected);
    });
  });

  group('applyDailyClear', () {
    test('first clear sets current to 1', () {
      final result = StreakCalculator.applyDailyClear(
        streak: streak(),
        todayId: '20260915',
      );
      expect(result.current, 1);
      expect(result.longest, 1);
      expect(result.lastClearedDateId, '20260915');
      expect(result.freezeAvailable, isTrue);
    });

    test('same-day clear is idempotent', () {
      final existing = streak(current: 3, longest: 5, last: '20260915');
      final result = StreakCalculator.applyDailyClear(
        streak: existing,
        todayId: '20260915',
      );
      expect(result.current, 3);
      expect(result.longest, 5);
      expect(result.freezeAvailable, isTrue);
    });

    test('gap 1 increments current', () {
      final result = StreakCalculator.applyDailyClear(
        streak: streak(current: 2, longest: 2, last: '20260914'),
        todayId: '20260915',
      );
      expect(result.current, 3);
      expect(result.longest, 3);
      expect(result.freezeAvailable, isTrue);
    });

    test('gap 2 with freeze consumes freeze and increments', () {
      final result = StreakCalculator.applyDailyClear(
        streak: streak(current: 4, longest: 4, last: '20260913'),
        todayId: '20260915',
      );
      expect(result.current, 5);
      expect(result.longest, 5);
      expect(result.freezeAvailable, isFalse);
    });

    test('gap 2 without freeze resets to 1', () {
      final result = StreakCalculator.applyDailyClear(
        streak: streak(current: 4, longest: 4, last: '20260913', freeze: false),
        todayId: '20260915',
      );
      expect(result.current, 1);
      expect(result.longest, 4);
      expect(result.freezeAvailable, isFalse);
    });

    test('gap 3+ resets to 1 without consuming freeze', () {
      final result = StreakCalculator.applyDailyClear(
        streak: streak(current: 4, longest: 4, last: '20260912'),
        todayId: '20260915',
      );
      expect(result.current, 1);
      expect(result.longest, 4);
      expect(result.freezeAvailable, isTrue);
    });

    test('longest does not decrease', () {
      final result = StreakCalculator.applyDailyClear(
        streak: streak(
          current: 2,
          longest: 10,
          last: '20260912',
          freeze: false,
        ),
        todayId: '20260915',
      );
      expect(result.current, 1);
      expect(result.longest, 10);
    });
  });

  group('applyLazyDecay', () {
    test('never cleared returns empty', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: streak(longest: 5),
        todayId: '20260915',
      );
      expect(result.streak.current, 0);
      expect(result.shouldPersist, isFalse);
    });

    test('daysSince 0 unchanged', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: streak(current: 3, longest: 3, last: '20260915'),
        todayId: '20260915',
      );
      expect(result.streak.current, 3);
      expect(result.streak.isOnFreeze, isFalse);
      expect(result.shouldPersist, isFalse);
    });

    test('daysSince 1 unchanged', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: streak(current: 3, longest: 3, last: '20260914'),
        todayId: '20260915',
      );
      expect(result.streak.current, 3);
      expect(result.shouldPersist, isFalse);
    });

    test('daysSince 2 with freeze marks on freeze without persist', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: streak(current: 3, longest: 3, last: '20260913'),
        todayId: '20260915',
      );
      expect(result.streak.current, 3);
      expect(result.streak.isOnFreeze, isTrue);
      expect(result.streak.freezeAvailable, isTrue);
      expect(result.shouldPersist, isFalse);
    });

    test('daysSince 2 without freeze resets and persists', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: streak(current: 3, longest: 3, last: '20260913', freeze: false),
        todayId: '20260915',
      );
      expect(result.streak.current, 0);
      expect(result.streak.longest, 3);
      expect(result.shouldPersist, isTrue);
    });

    test('daysSince 3+ resets and persists', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: streak(current: 3, longest: 3, last: '20260912'),
        todayId: '20260915',
      );
      expect(result.streak.current, 0);
      expect(result.streak.freezeAvailable, isTrue);
      expect(result.shouldPersist, isTrue);
    });
  });
}
