import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_stars.dart';
import 'package:winklo/features/results/results_args.dart';

void main() {
  test('the goal ticks agree with starsFor in every case', () {
    for (final hints in [false, true]) {
      for (final target in <int?>[null, 0, 30]) {
        for (final seconds in [0, 20, 30, 31]) {
          final stars = starsFor(
            usedHints: hints,
            seconds: seconds,
            targetSeconds: target,
          );
          final info = LevelResultInfo(
            runStars: stars,
            bestStars: stars,
            usedHints: hints,
            targetSeconds: target,
          );
          final expected =
              target != null && target > 0 && seconds >= 1 && seconds <= target;
          expect(
            info.timeEarned,
            expected,
            reason: 'hints $hints, target $target, seconds $seconds',
          );
          expect(info.noHintsEarned, !hints);
        }
      }
    }
  });

  test('which goals the run earned, from its stars', () {
    const clean = LevelResultInfo(
      runStars: 3,
      bestStars: 3,
      usedHints: false,
      targetSeconds: 30,
    );
    expect(clean.noHintsEarned, isTrue);
    expect(clean.timeEarned, isTrue);
    const slowClean = LevelResultInfo(
      runStars: 2,
      bestStars: 2,
      usedHints: false,
      targetSeconds: 30,
    );
    expect(slowClean.timeEarned, isFalse);
    const fastHinted = LevelResultInfo(
      runStars: 2,
      bestStars: 2,
      usedHints: true,
      targetSeconds: 30,
    );
    expect(fastHinted.noHintsEarned, isFalse);
    expect(fastHinted.timeEarned, isTrue);
    const noTarget = LevelResultInfo(
      runStars: 2,
      bestStars: 2,
      usedHints: false,
    );
    expect(noTarget.timeEarned, isFalse);
  });

  test('more stars than before, and a new world next', () {
    const info = LevelResultInfo(
      runStars: 3,
      bestStars: 3,
      previousStars: 2,
      usedHints: false,
      nextLocation: '/zip?mode=level&level=zip_2_01',
      nextWorldTheme: 'metro',
    );
    expect(info.moreStars, isTrue);
    expect(info.opensNewWorld, isTrue);
  });

  test('no extra stars or new world when there are none', () {
    const first = LevelResultInfo(runStars: 3, bestStars: 3, usedHints: false);
    expect(first.moreStars, isFalse);
    const same = LevelResultInfo(
      runStars: 2,
      bestStars: 2,
      previousStars: 2,
      usedHints: false,
    );
    expect(same.moreStars, isFalse);
    expect(first.opensNewWorld, isFalse);
  });
}
