import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/game_streak.dart';

void main() {
  group('freezeCount', () {
    test('the default streak has one freeze', () {
      const streak = GameStreak(gameId: 'zip');
      expect(streak.freezeCount, 1);
      expect(streak.freezeAvailable, isTrue);
    });

    test('freezeAvailable: false maps to a count of 0', () {
      const streak = GameStreak(gameId: 'zip', freezeAvailable: false);
      expect(streak.freezeCount, 0);
      expect(streak.freezeAvailable, isFalse);
    });

    test('freezeCount wins over freezeAvailable', () {
      const streak = GameStreak(
        gameId: 'zip',
        freezeCount: 2,
        freezeAvailable: false,
      );
      expect(streak.freezeCount, 2);
    });

    test('freezeAvailable reads as count > 0', () {
      expect(
        const GameStreak(gameId: 'zip', freezeCount: 0).freezeAvailable,
        isFalse,
      );
      expect(
        const GameStreak(gameId: 'zip', freezeCount: 2).freezeAvailable,
        isTrue,
      );
    });

    test('copyWith keeps or replaces the count', () {
      const streak = GameStreak(gameId: 'zip', freezeCount: 2);
      expect(streak.copyWith(current: 3).freezeCount, 2);
      expect(streak.copyWith(freezeCount: 0).freezeCount, 0);
      expect(streak.copyWith(freezeAvailable: false).freezeCount, 0);
      expect(
        const GameStreak(
          gameId: 'zip',
          freezeCount: 0,
        ).copyWith(freezeAvailable: true).freezeCount,
        1,
      );
    });

    test('the limits are two freezes, one per 7 days', () {
      expect(GameStreak.maxFreezes, 2);
      expect(GameStreak.freezeEarnEvery, 7);
    });
  });
}
