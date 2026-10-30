import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';

import '../../helpers/level_fixtures.dart';

void main() {
  final catalog = LevelCatalog([
    levelWorld(1, 3),
    levelWorld(2, 2, theme: 'metro'),
  ]);

  LevelMap map(Map<String, LevelRecord> records) =>
      LevelMap.build(catalog, LevelProgress(records));

  test('a new player: Level 1 is current, everything else locked', () {
    final m = map(const {});
    expect(m.currentId, 'zip_1_01');
    expect(m.node('zip_1_01')!.state, LevelNodeState.current);
    expect(m.node('zip_1_02')!.state, LevelNodeState.locked);
    expect(m.isPlayable('zip_1_01'), isTrue);
    expect(m.isPlayable('zip_1_02'), isFalse);
    expect(m.worlds[0].open, isTrue);
    expect(m.worlds[1].open, isFalse);
    expect(m.stars, 0);
    expect(m.maxStars, 15);
  });

  test('cleared levels are done; the first uncleared one is current', () {
    final m = map(const {
      'zip_1_01': LevelRecord(stars: 3, bestSeconds: 10),
      'zip_1_02': LevelRecord(stars: 2, bestSeconds: 40),
    });
    expect(m.node('zip_1_01')!.state, LevelNodeState.done);
    expect(m.node('zip_1_02')!.stars, 2);
    expect(m.currentId, 'zip_1_03');
    expect(m.worlds[0].stars, 5);
    expect(m.worlds[0].maxStars, 9);
    expect(m.worlds[0].lastNumber, 3);
  });

  test('clearing a world opens the next one', () {
    final m = map(const {
      'zip_1_01': LevelRecord(stars: 1, bestSeconds: 9),
      'zip_1_02': LevelRecord(stars: 1, bestSeconds: 9),
      'zip_1_03': LevelRecord(stars: 1, bestSeconds: 9),
    });
    expect(m.currentId, 'zip_2_01');
    expect(m.worlds[1].open, isTrue);
  });

  test('everything cleared: no current level', () {
    final all = {
      for (final id in [
        'zip_1_01',
        'zip_1_02',
        'zip_1_03',
        'zip_2_01',
        'zip_2_02',
      ])
        id: const LevelRecord(stars: 3, bestSeconds: 5),
    };
    final m = map(all);
    expect(m.currentId, isNull);
    expect(m.allCleared, isTrue);
    expect(m.isPlayable('zip_2_02'), isTrue);
  });

  test('a level without a time goal is worth two stars', () {
    final m = LevelMap.build(
      LevelCatalog([levelWorld(1, 2, targetSeconds: null)]),
      LevelProgress.empty,
    );
    expect(m.maxStars, 4);
  });

  test('an unknown id is not playable; an empty catalog is empty', () {
    expect(map(const {}).isPlayable('zip_9_01'), isFalse);
    final empty = LevelMap.build(LevelCatalog(const []), LevelProgress.empty);
    expect(empty.isEmpty, isTrue);
    expect(empty.allCleared, isFalse);
  });

  test('stars are clamped to what the level can give', () {
    final m = LevelMap.build(
      LevelCatalog([levelWorld(1, 1, targetSeconds: null)]),
      const LevelProgress({'zip_1_01': LevelRecord(stars: 3, bestSeconds: 5)}),
    );
    expect(m.node('zip_1_01')!.stars, 2);
    expect(m.stars, 2);
  });

  test('out-of-order progress keeps the first uncleared level current', () {
    final m = map(const {'zip_2_01': LevelRecord(stars: 1, bestSeconds: 9)});
    expect(m.currentId, 'zip_1_01');
    expect(m.node('zip_2_01')!.state, LevelNodeState.done);
    expect(m.isPlayable('zip_2_01'), isTrue);
    expect(m.node('zip_2_02')!.state, LevelNodeState.locked);
    expect(m.worlds[1].open, isTrue);
  });

  test('progress for an id not in the catalog is ignored', () {
    final m = map(const {'zip_9_01': LevelRecord(stars: 3, bestSeconds: 5)});
    expect(m.stars, 0);
    expect(m.currentId, 'zip_1_01');
  });

  test('a world with no levels is left out', () {
    final c = LevelCatalog([
      levelWorld(1, 1),
      levelWorld(2, 0),
      levelWorld(3, 1),
    ]);
    final m = LevelMap.build(
      c,
      const LevelProgress({'zip_1_01': LevelRecord(stars: 1, bestSeconds: 9)}),
    );
    expect(m.worlds.length, 2);
    expect(m.currentId, 'zip_3_01');
    expect(m.worlds[1].open, isTrue);
  });
}
