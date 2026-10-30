import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_catalog.dart';

import '../../helpers/level_fixtures.dart';

void main() {
  final ink = levelWorld(1, 3);
  final metro = levelWorld(2, 2, theme: 'metro');

  test('numbers levels across worlds, in world order', () {
    final catalog = LevelCatalog([metro, ink]);
    expect(catalog.worlds.map((w) => w.order), [1, 2]);
    expect(catalog.levelCount, 5);
    expect(catalog.slot('zip_1_01')!.number, 1);
    expect(catalog.slot('zip_1_03')!.number, 3);
    expect(catalog.slot('zip_2_01')!.number, 4);
    expect(catalog.slot('zip_2_01')!.indexInWorld, 0);
  });

  test('knows the next level and when it starts a new world', () {
    final catalog = LevelCatalog([ink, metro]);
    final second = catalog.slot('zip_1_02')!;
    expect(second.nextId, 'zip_1_03');
    expect(second.opensNewWorld, isFalse);
    final lastInk = catalog.slot('zip_1_03')!;
    expect(lastInk.nextId, 'zip_2_01');
    expect(lastInk.opensNewWorld, isTrue);
    expect(lastInk.nextWorld!.theme, 'metro');
    final last = catalog.slot('zip_2_02')!;
    expect(last.nextId, isNull);
    expect(last.opensNewWorld, isFalse);
  });

  test('an unknown id and an empty catalog', () {
    expect(LevelCatalog([ink]).slot('zip_9_01'), isNull);
    expect(LevelCatalog(const []).isEmpty, isTrue);
  });
}
