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

  GameStreak counted({
    int current = 0,
    int longest = 0,
    String? last,
    int freezes = 1,
  }) {
    return GameStreak(
      gameId: gameId,
      current: current,
      longest: longest,
      lastClearedDateId: last,
      freezeCount: freezes,
    );
  }

  group('earning freezes', () {
    test('a clear reaching day 7 earns a freeze', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 6, longest: 6, last: '20260914', freezes: 0),
        todayId: '20260915',
      );
      expect(result.streak.current, 7);
      expect(result.streak.freezeCount, 1);
      expect(result.freezeSpent, isFalse);
      expect(result.freezeEarned, isTrue);
    });

    test('day 14 earns a second one', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 13, longest: 13, last: '20260914'),
        todayId: '20260915',
      );
      expect(result.streak.current, 14);
      expect(result.streak.freezeCount, 2);
    });

    test('the count never passes 2', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 20, longest: 20, last: '20260914', freezes: 2),
        todayId: '20260915',
      );
      expect(result.streak.current, 21);
      expect(result.streak.freezeCount, 2);
      expect(result.freezeEarned, isFalse);
    });

    test('day 8 earns nothing', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 7, longest: 7, last: '20260914'),
        todayId: '20260915',
      );
      expect(result.streak.current, 8);
      expect(result.streak.freezeCount, 1);
      expect(result.freezeEarned, isFalse);
    });

    test('a reset to 1 earns nothing', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 6, longest: 6, last: '20260910', freezes: 0),
        todayId: '20260915',
      );
      expect(result.streak.current, 1);
      expect(result.streak.freezeCount, 0);
    });

    test('clearing the same day twice earns once', () {
      final first = StreakCalculator.dailyClear(
        streak: counted(current: 6, longest: 6, last: '20260914', freezes: 0),
        todayId: '20260915',
      );
      final again = StreakCalculator.dailyClear(
        streak: first.streak,
        todayId: '20260915',
      );
      expect(again.streak.current, 7);
      expect(again.streak.freezeCount, 1);
      expect(again.freezeEarned, isFalse);
      expect(again.freezeSpent, isFalse);
    });

    test('a first clear keeps the starting freeze', () {
      final result = StreakCalculator.dailyClear(
        streak: const GameStreak(gameId: gameId),
        todayId: '20260915',
      );
      expect(result.streak.current, 1);
      expect(result.streak.freezeCount, 1);
    });
  });

  group('spending freezes', () {
    test('a 2-day gap spends one and keeps the streak', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 4, longest: 4, last: '20260913'),
        todayId: '20260915',
      );
      expect(result.streak.current, 5);
      expect(result.streak.freezeCount, 0);
      expect(result.freezeSpent, isTrue);
    });

    test('a 2-day gap with two freezes leaves one', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 15, longest: 15, last: '20260913', freezes: 2),
        todayId: '20260915',
      );
      expect(result.streak.current, 16);
      expect(result.streak.freezeCount, 1);
      expect(result.freezeSpent, isTrue);
    });

    test('a 2-day gap with none resets to 1', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 4, longest: 4, last: '20260913', freezes: 0),
        todayId: '20260915',
      );
      expect(result.streak.current, 1);
      expect(result.streak.longest, 4);
      expect(result.freezeSpent, isFalse);
    });

    test('a 3-day gap resets even with freezes and keeps them', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 9, longest: 9, last: '20260912', freezes: 2),
        todayId: '20260915',
      );
      expect(result.streak.current, 1);
      expect(result.streak.freezeCount, 2);
      expect(result.freezeSpent, isFalse);
    });

    test('a spend that lands on day 14 earns it back', () {
      final result = StreakCalculator.dailyClear(
        streak: counted(current: 13, longest: 13, last: '20260913'),
        todayId: '20260915',
      );
      expect(result.streak.current, 14);
      expect(result.streak.freezeCount, 1);
      expect(result.freezeSpent, isTrue);
      expect(result.freezeEarned, isTrue);
    });

    test('applyDailyClear returns the same streak as dailyClear', () {
      final input = counted(current: 6, longest: 6, last: '20260914');
      expect(
        StreakCalculator.applyDailyClear(
          streak: input,
          todayId: '20260915',
        ).freezeCount,
        StreakCalculator.dailyClear(
          streak: input,
          todayId: '20260915',
        ).streak.freezeCount,
      );
    });
  });

  group('lazy decay and the count', () {
    test('keeps the count while on a freeze', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: counted(current: 9, longest: 9, last: '20260913', freezes: 2),
        todayId: '20260915',
      );
      expect(result.streak.isOnFreeze, isTrue);
      expect(result.streak.freezeCount, 2);
    });

    test('keeps the count when a streak resets', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: counted(current: 9, longest: 9, last: '20260901', freezes: 2),
        todayId: '20260915',
      );
      expect(result.streak.current, 0);
      expect(result.streak.freezeCount, 2);
    });

    test('keeps the count of a streak that was never cleared', () {
      final result = StreakCalculator.applyLazyDecay(
        streak: counted(freezes: 0),
        todayId: '20260915',
      );
      expect(result.streak.freezeCount, 0);
    });
  });

  group('storedFreezeCount', () {
    int read({int? count, bool? available}) =>
        StreakCalculator.storedFreezeCount(count: count, available: available);

    test('a missing count reads freezeAvailable', () {
      expect(read(available: true), 1);
      expect(read(available: false), 0);
      expect(read(), 1);
    });

    test('a consistent count is used', () {
      expect(read(count: 2, available: true), 2);
      expect(read(count: 1, available: true), 1);
      expect(read(count: 0, available: false), 0);
      expect(read(count: 2), 2);
    });

    test('out-of-range counts clamp to 0..2', () {
      expect(read(count: 5, available: true), 2);
      expect(read(count: -1, available: false), 0);
    });

    test('true with a count of 0 (an older build wrote after) reads 1', () {
      expect(read(count: 0, available: true), 1);
    });

    test('false with a count (an older build spent one) reads one less', () {
      expect(read(count: 2, available: false), 1);
      expect(read(count: 1, available: false), 0);
    });
  });

  group('atStakeTomorrow', () {
    const today = '20260915';

    test('a streak cleared today is at stake tomorrow', () {
      expect(
        StreakCalculator.atStakeTomorrow(
          streak: counted(current: 5, longest: 5, last: today, freezes: 0),
          todayId: today,
        ),
        5,
      );
    });

    test('a streak last cleared yesterday survives only with a freeze', () {
      expect(
        StreakCalculator.atStakeTomorrow(
          streak: counted(current: 5, longest: 5, last: '20260914'),
          todayId: today,
        ),
        5,
      );
      expect(
        StreakCalculator.atStakeTomorrow(
          streak: counted(current: 5, longest: 5, last: '20260914', freezes: 0),
          todayId: today,
        ),
        0,
      );
    });

    test('a streak on a freeze today is gone tomorrow', () {
      expect(
        StreakCalculator.atStakeTomorrow(
          streak: counted(current: 5, longest: 5, last: '20260913'),
          todayId: today,
        ),
        0,
      );
    });

    test('no clear means nothing at stake', () {
      expect(
        StreakCalculator.atStakeTomorrow(streak: counted(), todayId: today),
        0,
      );
    });
  });
}
