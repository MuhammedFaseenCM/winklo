import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/domain/achievements/next_achievement.dart';
import 'package:winklo/domain/game_ids.dart';

const _firstClears = {
  'first_clear_zip',
  'first_clear_path_words',
  'first_clear_sudoku',
};

void main() {
  test('nothing earned: the first Zip clear', () {
    expect(nextAchievement(const {})?.id, 'first_clear_zip');
  });

  test('first clears go before streaks with no progress', () {
    expect(
      nextAchievement(const {'first_clear_zip'})?.id,
      'first_clear_path_words',
    );
  });

  test('a running streak points at its next streak badge', () {
    expect(
      nextAchievement(
        _firstClears,
        currentStreakByGame: const {GameIds.pathWords: 4},
      )?.id,
      'streak_7_path_words',
    );
  });

  test('the streak with the most progress wins', () {
    final next = nextAchievement(
      {
        ..._firstClears,
        'streak_7_zip',
        'streak_7_path_words',
        'streak_7_sudoku',
      },
      currentStreakByGame: const {GameIds.zip: 5, GameIds.sudoku: 20},
    );
    expect(next?.id, 'streak_30_sudoku');
  });

  test('a running streak beats a locked first clear', () {
    expect(
      nextAchievement(
        const {'first_clear_zip'},
        currentStreakByGame: const {GameIds.zip: 3},
      )?.id,
      'streak_7_zip',
    );
  });

  test('a streak past its target that is not stored yet still leads', () {
    expect(
      nextAchievement(
        _firstClears,
        currentStreakByGame: const {GameIds.zip: 9, GameIds.sudoku: 5},
      )?.id,
      'streak_7_zip',
    );
  });

  test('everything earned: nothing next', () {
    expect(nextAchievement({for (final a in Achievements.all) a.id}), isNull);
  });
}
