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
    test('streak reminder names one streak', () {
      expect(
        AppStrings.notifStreakEndsTonight(GameIds.zip, 12),
        'Your 12-day Zip streak ends at midnight',
      );
    });

    test('streak reminder counts the others at risk', () {
      expect(
        AppStrings.notifStreakEndsTonight(GameIds.pathWords, 5, others: 2),
        'Your 5-day Path Words streak and 2 more end at midnight',
      );
      expect(
        AppStrings.notifStreakEndsTonight(GameIds.sudoku, 1, others: 1),
        'Your 1-day Sudoku streak and 1 more end at midnight',
      );
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
