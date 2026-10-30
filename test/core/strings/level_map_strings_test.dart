import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';

void main() {
  test('map copy in English', () {
    expect(AppStrings.levelsSoon, 'Soon');
    expect(
      AppStrings.levelsNeedConnection,
      'Levels need a connection the first time.',
    );
    expect(AppStrings.levelsComingSoon, 'Levels are coming soon.');
    expect(AppStrings.levelWorldTitle(2, 'metro'), 'World 2 · Metro');
    expect(AppStrings.levelWorldLocked(20), 'Clear Level 20 to open');
    expect(AppStrings.levelLocked(5), 'Clear Level 5 first');
    expect(AppStrings.levelLockedMessage, 'This level is still locked.');
    expect(AppStrings.levelPlay, 'Play');
    expect(AppStrings.levelBestTime('0:17'), 'Best 0:17');
    expect(AppStrings.levelBackToMap, 'Map');
    expect(AppStrings.levelNodeDone(4, 2, 3), 'Level 4, 2 of 3 stars');
    expect(AppStrings.levelNodeCurrent(5), 'Level 5, next to play');
    expect(AppStrings.levelNodeLocked(6), 'Level 6, locked');
    expect(AppStrings.levelNumber(4), 'Level 4');
  });

  test('the Levels tab icon has a fill layer', () {
    expect(AppIcons.duotoneFill(AppIcons.levels), isNotNull);
    expect(AppIcons.levelsSelected.codePoint, 0xe31a);
  });
}
