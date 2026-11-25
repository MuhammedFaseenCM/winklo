import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/get_levels_overview.dart';

import '../../helpers/level_fixtures.dart';

class _Worlds extends Mock implements LevelWorldRepository {}

class _Progress extends Mock implements LevelProgressRepository {}

void main() {
  late _Worlds worlds;
  late _Progress progress;

  setUp(() {
    worlds = _Worlds();
    progress = _Progress();
    when(
      () => worlds.catalog(GameIds.zip),
    ).thenAnswer((_) async => LevelCatalog([levelWorld(1, 5)]));
    when(
      () => worlds.catalog(GameIds.pathWords),
    ).thenAnswer((_) async => LevelCatalog([pathWordsWorld(1, 5)]));
    when(
      () => progress.progress(GameIds.zip),
    ).thenReturn(const LevelProgress({}));
    when(() => progress.progress(GameIds.pathWords)).thenReturn(
      const LevelProgress({
        'path_words_1_01': LevelRecord(stars: 3, bestSeconds: 9),
        'path_words_1_02': LevelRecord(stars: 2, bestSeconds: 9),
        'path_words_1_03': LevelRecord(stars: 1, bestSeconds: 9),
      }),
    );
  });

  test('each game\'s next level and stars', () async {
    final overview = await GetLevelsOverview(worlds, progress)();
    final zip = overview.of(GameIds.zip)!;
    expect(zip.nextLevelId, 'zip_1_01');
    expect(zip.nextNumber, 1);
    expect(zip.stars, 0);
    final words = overview.of(GameIds.pathWords)!;
    expect(words.nextLevelId, 'path_words_1_04');
    expect(words.nextNumber, 4);
    expect(words.stars, 6);
    expect(overview.totalStars, 6);
  });

  test('a game whose worlds can\'t load is left out, not fatal', () async {
    when(
      () => worlds.catalog(GameIds.zip),
    ).thenThrow(const LevelsUnavailable('offline'));
    final overview = await GetLevelsOverview(worlds, progress)();
    expect(overview.of(GameIds.zip), isNull);
    expect(overview.of(GameIds.pathWords)?.nextNumber, 4);
  });

  test('a game with every level cleared points at its last level', () async {
    when(() => progress.progress(GameIds.zip)).thenReturn(
      LevelProgress({
        for (var n = 1; n <= 5; n++)
          levelId(1, n): const LevelRecord(stars: 3, bestSeconds: 9),
      }),
    );
    final zip = (await GetLevelsOverview(worlds, progress)()).of(GameIds.zip)!;
    expect(zip.nextLevelId, 'zip_1_05');
    expect(zip.allCleared, isTrue);
  });
}
