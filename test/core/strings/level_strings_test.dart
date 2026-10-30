import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';

void main() {
  test('level copy in English', () {
    expect(AppStrings.levelsTitle, 'Levels');
    expect(AppStrings.levelWorldName('ink'), 'Ink');
    expect(AppStrings.levelWorldName('sparkler'), 'Sparkler');
    expect(AppStrings.levelWorldName('unknown'), 'Levels');
    expect(AppStrings.levelRunLabel(27, 'metro'), 'Level 27 · Metro');
    expect(AppStrings.levelClearedTitle(7), 'Level 7 cleared');
    expect(AppStrings.levelHintCostsStar, 'Hint · costs a star');
    expect(AppStrings.levelTarget('0:30'), 'Target 0:30');
    expect(AppStrings.levelGoalUnder('0:30'), 'Under 0:30');
    expect(AppStrings.levelNewBestStars(2, 3), 'New best · 2 → 3 stars');
    expect(AppStrings.levelOpenWorld('Metro'), 'Open Metro');
  });
}
