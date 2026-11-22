import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/level_world.dart';

void main() {
  test('level copy in English', () {
    expect(AppStrings.levelsTitle, 'Levels');
    expect(AppStrings.levelWorldName('ink'), 'Ink');
    expect(AppStrings.levelWorldName('sparkler'), 'Sparkler');
    expect(AppStrings.levelWorldName('unknown'), 'Levels');
    expect(AppStrings.levelRunLabel(27, 'Metro'), 'Level 27 · Metro');
    expect(AppStrings.levelClearedTitle(7), 'Level 7 cleared');
    expect(AppStrings.levelHintCostsStar, 'Hint · costs a star');
    expect(AppStrings.levelTarget('0:30'), 'Target 0:30');
    expect(AppStrings.levelGoalUnder('0:30'), '0:30 or less');
    expect(AppStrings.levelNewBestStars(2, 3), 'New best · 2 → 3 stars');
    expect(AppStrings.levelOpenWorld('Metro'), 'Open Metro');
  });

  test('levelWorldDisplayName', () {
    final animals = LevelWorld(
      id: 'path_words_1',
      game: 'path_words',
      order: 1,
      theme: 'animals',
      title: 'Animals',
      levels: const [],
    );
    final ink = LevelWorld(
      id: 'zip_1',
      game: 'zip',
      order: 1,
      theme: 'ink',
      levels: const [],
    );
    final untitled = LevelWorld(
      id: 'path_words_2',
      game: 'path_words',
      order: 2,
      theme: 'ink',
      levels: const [],
    );
    expect(AppStrings.levelWorldDisplayName(animals), 'Animals');
    expect(AppStrings.levelWorldDisplayName(ink), 'Ink');
    expect(AppStrings.levelWorldDisplayName(untitled), 'Ink');
    AppStrings.use('ml');
    addTearDown(() => AppStrings.use('en'));
    expect(AppStrings.levelWorldDisplayName(animals), 'Animals');
  });
}
