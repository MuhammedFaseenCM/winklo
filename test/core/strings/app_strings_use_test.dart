import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';

void main() {
  tearDown(() => AppStrings.use('en'));

  test('reads English by default', () {
    expect(AppStrings.languageCode, 'en');
    expect(AppStrings.retry, 'Retry');
    expect(AppStrings.zipHintWithCount(2), 'Hint (2)');
  });

  test('use(ml) switches getters and methods to Malayalam', () {
    AppStrings.use('ml');
    expect(AppStrings.languageCode, 'ml');
    expect(AppStrings.retry, 'വീണ്ടും ശ്രമിക്കൂ');
    expect(AppStrings.zipHintWithCount(2), 'സൂചന (2)');
    AppStrings.use('en');
    expect(AppStrings.retry, 'Retry');
  });

  test('a language without a table reads English', () {
    AppStrings.use('ml');
    AppStrings.use('xx');
    expect(AppStrings.languageCode, 'en');
    expect(AppStrings.retry, 'Retry');
  });

  test('formatPlayTime is the same in every language', () {
    AppStrings.use('ml');
    expect(AppStrings.formatPlayTime(48), '0:48');
    expect(AppStrings.formatPlayTime(605), '10:05');
  });

  group('Malayalam keeps its word order around values', () {
    setUp(() => AppStrings.use('ml'));

    test('dates read month then day, as CLDR ml', () {
      expect(AppStrings.leaderboardShortDate(9, 10), 'ഒക്ടോ 9');
      expect(
        AppStrings.shareHeadline('Zip', DateTime(2026, 10, 9)),
        'Winklo Zip · ഒക്ടോ 9',
      );
    });

    test('counts come before the noun', () {
      expect(
        AppStrings.homeTodaySummary(cleared: 2, total: 3, totalSeconds: 221),
        '3-ൽ 2 പൂർത്തിയായി · ആകെ 3:41',
      );
      expect(AppStrings.achievementsProgress(3, 8), '8-ൽ 3');
    });

    test('the new-puzzle countdown needs no case ending', () {
      expect(
        AppStrings.newPuzzleIn(const Duration(hours: 6, minutes: 12)),
        'പുതിയ പസിലിന് ഇനി 6 മ. 12 മി.',
      );
      expect(
        AppStrings.newPuzzleIn(const Duration(seconds: 5)),
        'പുതിയ പസിലിന് ഇനി 1 മി.',
      );
      expect(AppStrings.newPuzzleIn(Duration.zero), AppStrings.newPuzzleReady);
    });

    test('the streak reminder joins "and 2 more" to the streak', () {
      expect(
        AppStrings.notifStreakEndsTonight(GameIds.zip, 12),
        'നിങ്ങളുടെ 12 ദിവസത്തെ Zip സ്ട്രീക്ക് അർധരാത്രി അവസാനിക്കും',
      );
      expect(
        AppStrings.notifStreakEndsTonight(GameIds.zip, 12, others: 2),
        'നിങ്ങളുടെ 12 ദിവസത്തെ Zip സ്ട്രീക്കും മറ്റ് 2 എണ്ണവും അർധരാത്രി '
        'അവസാനിക്കും',
      );
    });

    test('the weekly recap', () {
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
        'ഈ ആഴ്ച: 21-ൽ 18 പൂർത്തിയാക്കി, മികച്ച Zip 0:58, 5 ദിവസത്തെ '
        'Sudoku സ്ട്രീക്ക്',
      );
    });

    test('Sudoku hints put the unit in the locative', () {
      for (final (unit, inThis) in [
        (AppStrings.sudokuHintUnitRow, 'ഈ വരിയിലെ'),
        (AppStrings.sudokuHintUnitColumn, 'ഈ നിരയിലെ'),
        (AppStrings.sudokuHintUnitRegion, 'ഈ ബോക്സിലെ'),
      ]) {
        expect(
          AppStrings.sudokuHintLastRemaining(digit: 4, unit: unit),
          startsWith(inThis),
        );
      }
    });

    test('game names stay English', () {
      expect(AppStrings.zipTitle, 'Zip');
      expect(AppStrings.pathWordsTitle, 'Path Words');
      expect(AppStrings.sudokuTitle, 'Sudoku');
      expect(AppStrings.playTodaysZip, contains('Zip'));
    });
  });
}
