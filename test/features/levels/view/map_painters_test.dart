import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/features/levels/logic/level_map_layout.dart';
import 'package:winklo/features/levels/view/widgets/level_path_painter.dart';
import 'package:winklo/features/levels/view/widgets/world_backdrop_painter.dart';

import '../../../helpers/level_fixtures.dart';

void main() {
  LevelMapLayout layoutWith(Map<String, LevelRecord> records) =>
      LevelMapLayout.of(
        LevelMap.build(
          LevelCatalog([
            levelWorld(1, 3),
            levelWorld(2, 2, theme: 'metro'),
            levelWorld(3, 1, theme: 'mystery'),
          ]),
          LevelProgress(records),
        ),
        390,
      );

  testWidgets('both painters draw every kind of world without errors', (
    tester,
  ) async {
    final layout = layoutWith(const {
      'zip_1_01': LevelRecord(stars: 3, bestSeconds: 9),
      'zip_1_02': LevelRecord(stars: 3, bestSeconds: 9),
      'zip_1_03': LevelRecord(stars: 3, bestSeconds: 9),
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: WorldBackdropPainter(layout.bands),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: LevelPathPainter(layout)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('painters repaint only for a new layout', () {
    final a = layoutWith(const {});
    final b = layoutWith(const {});
    expect(
      WorldBackdropPainter(
        a.bands,
      ).shouldRepaint(WorldBackdropPainter(a.bands)),
      isFalse,
    );
    expect(
      WorldBackdropPainter(
        a.bands,
      ).shouldRepaint(WorldBackdropPainter(b.bands)),
      isTrue,
    );
    expect(LevelPathPainter(a).shouldRepaint(LevelPathPainter(a)), isFalse);
    expect(LevelPathPainter(a).shouldRepaint(LevelPathPainter(b)), isTrue);
  });
}
