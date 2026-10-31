import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/logic/level_map_layout.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 3), levelWorld(2, 2, theme: 'metro')]),
    LevelProgress.empty,
  );
  const width = 390.0;
  final layout = LevelMapLayout.of(map, width);
  double y(String id) => layout.centers[id]!.dy;

  test('height fits every level and the gap between worlds', () {
    expect(
      layout.size.height,
      LevelMapLayout.topPad +
          LevelMapLayout.bottomPad +
          4 * LevelMapLayout.step +
          (LevelMapLayout.gateGap - LevelMapLayout.step),
    );
    expect(layout.size.width, width);
  });

  test('Level 1 is at the bottom and the path climbs', () {
    expect(y('zip_1_01'), layout.size.height - LevelMapLayout.bottomPad);
    final ids = ['zip_1_01', 'zip_1_02', 'zip_1_03', 'zip_2_01', 'zip_2_02'];
    for (var i = 1; i < ids.length; i++) {
      expect(y(ids[i]), lessThan(y(ids[i - 1])));
    }
    expect(y('zip_1_03') - y('zip_2_01'), LevelMapLayout.gateGap);
  });

  test('levels wind around the middle', () {
    final amp = width * LevelMapLayout.amplitudeFraction;
    for (final c in layout.centers.values) {
      expect(
        c.dx,
        inInclusiveRange(width / 2 - amp - 0.01, width / 2 + amp + 0.01),
      );
    }
    expect(layout.centers['zip_1_01']!.dx, closeTo(width / 2, 0.01));
    expect(layout.centers['zip_1_02']!.dx, closeTo(width / 2 + amp, 0.01));
  });

  test('world bands cover the map, top to bottom, with the gate between', () {
    expect(layout.bands.length, 2);
    expect(layout.bands[0].rect.bottom, layout.size.height);
    expect(layout.bands[1].rect.top, 0);
    expect(layout.bands[0].rect.top, layout.bands[1].rect.bottom);
    expect(layout.bands[1].gateY, (y('zip_1_03') + y('zip_2_01')) / 2);
    expect(layout.nodes.map((n) => n.slot.entry.id).first, 'zip_1_01');
  });

  test('an empty world takes no space', () {
    final withEmpty = LevelMap.build(
      LevelCatalog([levelWorld(1, 1), levelWorld(2, 0), levelWorld(3, 1)]),
      LevelProgress.empty,
    );
    expect(LevelMapLayout.of(withEmpty, width).bands.length, 2);
  });

  test('an empty map and a one-level map', () {
    final empty = LevelMapLayout.of(
      LevelMap.build(LevelCatalog(const []), LevelProgress.empty),
      width,
    );
    expect(empty.size.height, LevelMapLayout.topPad + LevelMapLayout.bottomPad);
    expect(empty.nodes, isEmpty);
    expect(empty.bands, isEmpty);
    final one = LevelMapLayout.of(
      LevelMap.build(LevelCatalog([levelWorld(1, 1)]), LevelProgress.empty),
      width,
    );
    expect(one.centers['zip_1_01']!.dy, LevelMapLayout.topPad);
    expect(one.bands.single.rect, Rect.fromLTRB(0, 0, width, one.size.height));
  });

  test('a short map stretches to minHeight, the extra going to the top', () {
    final one = LevelMapLayout.of(
      LevelMap.build(LevelCatalog([levelWorld(1, 1)]), LevelProgress.empty),
      width,
      minHeight: 900,
    );
    expect(one.size.height, 900);
    expect(one.centers['zip_1_01']!.dy, 900 - LevelMapLayout.bottomPad);
    expect(one.bands.single.rect, const Rect.fromLTRB(0, 0, width, 900));
  });

  test("a world's label sits on the side away from the line", () {
    // The line enters World 2 from Level 4 (left) to Level 5 (middle):
    // it crosses the gate left of centre, so the label goes right.
    final leftCross = LevelMapLayout.of(
      LevelMap.build(
        LevelCatalog([levelWorld(1, 4), levelWorld(2, 3, theme: 'metro')]),
        LevelProgress.empty,
      ),
      width,
    );
    expect(leftCross.labelOnRight(0), isFalse);
    expect(leftCross.labelOnRight(1), isTrue);
    // From Level 2 (right) to Level 3 (middle): crosses right, label left.
    final rightCross = LevelMapLayout.of(
      LevelMap.build(
        LevelCatalog([levelWorld(1, 2), levelWorld(2, 1, theme: 'metro')]),
        LevelProgress.empty,
      ),
      width,
    );
    expect(rightCross.labelOnRight(1), isFalse);
  });

  test(
    'bottomInset lifts Level 1 above it; the map still reaches the edge',
    () {
      final lifted = LevelMapLayout.of(map, width, bottomInset: 100);
      expect(lifted.bottomInset, 100);
      expect(lifted.size.height, layout.size.height + 100);
      expect(
        lifted.centers['zip_1_01']!.dy,
        lifted.size.height - 100 - LevelMapLayout.bottomPad,
      );
      expect(lifted.bands[0].rect.bottom, lifted.size.height);
      expect(layout.bottomInset, 0);

      final tall = LevelMapLayout.of(
        LevelMap.build(LevelCatalog([levelWorld(1, 1)]), LevelProgress.empty),
        width,
        minHeight: 900,
        bottomInset: 100,
      );
      expect(tall.size.height, 900);
      expect(tall.centers['zip_1_01']!.dy, 800 - LevelMapLayout.bottomPad);
    },
  );
}
