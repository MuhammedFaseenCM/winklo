import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_world.dart';

import '../../helpers/level_fixtures.dart';

void main() {
  test('parses a world and its levels in order', () {
    final world = LevelWorld.fromJson('zip_1', levelWorldJson(1, 3));
    expect(world.id, 'zip_1');
    expect(world.game, 'zip');
    expect(world.order, 1);
    expect(world.theme, 'ink');
    expect(world.levels.map((l) => l.id), ['zip_1_01', 'zip_1_02', 'zip_1_03']);
    expect(world.levels.first.targetSeconds, 30);
  });

  test('a level builds its Zip board under its own id', () {
    final entry = LevelEntry.fromJson(levelBoardJson('zip_1_01'));
    final board = entry.zipLevel;
    expect(board.id, 'zip_1_01');
    expect(board.size, 3);
    expect(board.solution.length, 9);
  });

  test('a missing, zero or negative target means no time goal', () {
    expect(LevelEntry.fromJson(levelBoardJson('a_1_01')).targetSeconds, isNull);
    expect(
      LevelEntry.fromJson(
        levelBoardJson('a_1_01', targetSeconds: 0),
      ).targetSeconds,
      isNull,
    );
    expect(
      LevelEntry.fromJson(
        levelBoardJson('a_1_01', targetSeconds: -5),
      ).targetSeconds,
      isNull,
    );
  });

  test('refuses a level without an id and a world without levels', () {
    expect(
      () => LevelEntry.fromJson(<String, dynamic>{'size': 3}),
      throwsFormatException,
    );
    expect(() => LevelEntry.fromJson('not a map'), throwsFormatException);
    expect(
      () => LevelWorld.fromJson('zip_1', {'game': 'zip', 'order': 1}),
      throwsFormatException,
    );
    expect(
      () => LevelWorld.fromJson('zip_1', {'game': 'zip', 'levels': []}),
      throwsFormatException,
    );
  });

  test('accepts a double target and rejects non-finite numbers', () {
    final board = levelBoardJson('a_1_01')..['targetSeconds'] = 20.0;
    expect(LevelEntry.fromJson(board).targetSeconds, 20);
    board['targetSeconds'] = double.nan;
    expect(LevelEntry.fromJson(board).targetSeconds, isNull);
    expect(
      () => LevelWorld.fromJson('zip_1', {
        'game': 'zip',
        'order': double.nan,
        'levels': [],
      }),
      throwsFormatException,
    );
  });

  test('refuses bad level entries and a non-numeric order', () {
    expect(
      () => LevelWorld.fromJson('zip_1', {
        'game': 'zip',
        'order': 1,
        'levels': [null],
      }),
      throwsFormatException,
    );
    expect(
      () => LevelWorld.fromJson('zip_1', {
        'game': 'zip',
        'order': '1',
        'levels': [],
      }),
      throwsFormatException,
    );
  });

  test('an empty levels list is a world with no levels', () {
    final world = LevelWorld.fromJson('zip_1', {
      'game': 'zip',
      'order': 1,
      'levels': [],
    });
    expect(world.levels, isEmpty);
  });

  test('fixture worlds can have levels without a time goal', () {
    final world = levelWorld(1, 2, targetSeconds: null);
    expect(world.levels.map((l) => l.targetSeconds), [null, null]);
  });
}
