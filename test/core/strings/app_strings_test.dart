import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';

void main() {
  group('newPuzzleIn', () {
    test('hours and minutes', () {
      expect(
        AppStrings.newPuzzleIn(const Duration(hours: 6, minutes: 12)),
        'New puzzle in 6h 12m',
      );
    });

    test('rounds a part minute up, so it never says 0m', () {
      expect(
        AppStrings.newPuzzleIn(
          const Duration(hours: 6, minutes: 11, seconds: 1),
        ),
        'New puzzle in 6h 12m',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(seconds: 5)),
        'New puzzle in 1m',
      );
    });

    test('drops zero minutes and zero hours', () {
      expect(
        AppStrings.newPuzzleIn(const Duration(hours: 3)),
        'New puzzle in 3h',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(minutes: 59, seconds: 30)),
        'New puzzle in 1h',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(minutes: 42)),
        'New puzzle in 42m',
      );
    });

    test('says the puzzle is ready once the time is up', () {
      expect(AppStrings.newPuzzleIn(Duration.zero), AppStrings.newPuzzleReady);
      expect(
        AppStrings.newPuzzleIn(const Duration(seconds: -3)),
        AppStrings.newPuzzleReady,
      );
    });
  });

  group('habit copy', () {
    test('every streak-at-risk line names its game', () {
      for (final (gameId, days) in [
        (GameIds.zip, 1),
        (GameIds.pathWords, 4),
        (GameIds.sudoku, 12),
        (GameIds.zip, 45),
      ]) {
        for (final line in AppStrings.notifStreakRiskLines(gameId, days)) {
          expect(
            '${line.title} ${line.body}',
            contains(AppStrings.gameTitle(gameId)),
            reason: '$gameId $days: $line',
          );
        }
      }
    });

    test('streak-at-risk lines suit how long the streak is', () {
      final young = AppStrings.notifStreakRiskLines(GameIds.zip, 1).toSet();
      final long = AppStrings.notifStreakRiskLines(GameIds.zip, 45).toSet();
      expect(young.intersection(long), isEmpty);
    });

    test('streak-at-risk lines count the other streaks at stake', () {
      expect(
        AppStrings.notifStreakRiskLines(
          GameIds.sudoku,
          1,
          others: 1,
        ).map((line) => line.body),
        everyElement(endsWith(' 1 more streak ends tonight too.')),
      );
      expect(
        AppStrings.notifStreakRiskLines(
          GameIds.pathWords,
          5,
          others: 2,
        ).map((line) => line.body),
        everyElement(endsWith(' 2 more streaks end tonight too.')),
      );
      expect(
        AppStrings.notifStreakRiskLines(
          GameIds.zip,
          12,
        ).map((line) => line.body),
        everyElement(isNot(contains('more streak'))),
      );
    });

    test('morning streak lines count on from the streak', () {
      final lines = AppStrings.notifMorningStreakLines(GameIds.zip, 12);
      expect(
        lines.map((line) => '${line.title} ${line.body}'),
        everyElement(allOf(contains('12'), contains('Zip'))),
      );
      expect(lines.first.title, 'Day 13 of your Zip streak 🔥');
    });

    test('freeze saved', () {
      expect(
        AppStrings.freezeSavedStreak(GameIds.zip, 12),
        'Your freeze saved your 12-day Zip streak',
      );
    });

    test('weekly recap with every part', () {
      const recap = WeeklyRecap(
        weekStartId: '20261012',
        cleared: 18,
        possible: 21,
        bestGameId: GameIds.zip,
        bestSeconds: 58,
        streakGameId: GameIds.sudoku,
        streakDays: 5,
      );
      expect(
        AppStrings.weeklyRecapLine(recap),
        'This week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak',
      );
      expect(
        AppStrings.weeklyRecapLine(recap, lastWeek: true),
        'Last week: 18 of 21 cleared, best Zip 0:58, 5-day Sudoku streak',
      );
    });

    test('weekly recap leaves out missing parts', () {
      const recap = WeeklyRecap(
        weekStartId: '20261012',
        cleared: 2,
        possible: 21,
      );
      expect(AppStrings.weeklyRecapLine(recap), 'This week: 2 of 21 cleared');
    });

    test('widget marks', () {
      expect(AppStrings.widgetStreak(12), '🔥12');
      expect(AppStrings.widgetCleared, '✓');
    });

    test('game titles by id', () {
      expect(AppStrings.gameTitle(GameIds.zip), AppStrings.zipTitle);
      expect(
        AppStrings.gameTitle(GameIds.pathWords),
        AppStrings.pathWordsTitle,
      );
      expect(AppStrings.gameTitle(GameIds.sudoku), AppStrings.sudokuTitle);
    });
  });
}
