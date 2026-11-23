import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/levels/view/widgets/backdrops/backdrops.dart';
import 'package:winklo/features/levels/view/widgets/level_theme_palette.dart';

/// Paints one band of [theme] into a [width]×[height] image's RGBA bytes.
Future<Uint8List> render(
  String theme, {
  required bool open,
  double width = 360,
  double height = 900,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintThemeBackdrop(
    canvas,
    Rect.fromLTWH(0, 0, width, height),
    theme,
    open: open,
    seed: 3,
  );
  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

Color pixel(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(rgba[i + 3], rgba[i], rgba[i + 1], rgba[i + 2]);
}

/// Rows (every 6th) whose colour changes across the band. A ground alone,
/// flat or a top-to-bottom gradient, is one colour along every row; a motif
/// breaks rows up.
int variedRows(Uint8List rgba) {
  var varied = 0;
  for (var y = 0; y < 900; y += 6) {
    final colours = <int>{
      for (var x = 0; x < 360; x += 3) pixel(rgba, 360, x, y).toARGB32(),
    };
    if (colours.length > 1) varied++;
  }
  return varied;
}

/// The colour seen most often over a sample grid.
int mostCommon(Uint8List rgba) {
  final counts = <int, int>{};
  for (var y = 0; y < 900; y += 5) {
    for (var x = 0; x < 360; x += 5) {
      final c = pixel(rgba, 360, x, y).toARGB32();
      counts[c] = (counts[c] ?? 0) + 1;
    }
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

const newThemes = [
  'embroidery',
  'neon',
  'sparkler',
  'animals',
  'food',
  'sports',
  'nature',
  'home',
  'body',
];

void main() {
  testWidgets('every theme paints open and locked at phone and tablet width', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final theme in [...LevelThemePalette.themes, 'mystery']) {
        for (final open in [true, false]) {
          for (final width in [360.0, 1080.0]) {
            await render(theme, open: open, width: width);
          }
        }
      }
    });
  });

  testWidgets(
    'a new theme\'s open band is its own ground, not the plain fill',
    (tester) async {
      await tester.runAsync(() async {
        for (final theme in newThemes) {
          final bytes = await render(theme, open: true);
          // A corner, clear of most motifs, is the ground (or its gradient).
          final corner = pixel(bytes, 360, 2, 2);
          expect(
            corner.toARGB32(),
            isNot(ZipColors.ink.toARGB32()),
            reason: theme,
          );
        }
      });
    },
  );

  testWidgets('a new theme draws a motif over its ground', (tester) async {
    await tester.runAsync(() async {
      for (final theme in newThemes) {
        final bytes = await render(theme, open: true);
        expect(variedRows(bytes), greaterThan(20), reason: theme);
      }
    });
  });

  testWidgets('the plain look has no motif', (tester) async {
    await tester.runAsync(() async {
      expect(variedRows(await render('mystery', open: true)), 0);
    });
  });

  testWidgets('a locked themed world previews its own motif', (tester) async {
    await tester.runAsync(() async {
      final unprinted = await render('ink', open: false);
      for (final theme in newThemes) {
        final locked = await render(theme, open: false);
        // Still close to the app's ink ground, so it reads as not open
        // yet (a faded motif over it, never the world's own colours)...
        final ground = Color(mostCommon(locked));
        for (final (got, want) in [
          (ground.r, ZipColors.ink.r),
          (ground.g, ZipColors.ink.g),
          (ground.b, ZipColors.ink.b),
        ]) {
          expect((got - want).abs(), lessThan(0.1), reason: theme);
        }
        // ...but drawn in its own motif, not the metro outlines.
        expect(locked, isNot(unprinted), reason: theme);
        expect(variedRows(locked), greaterThan(10), reason: theme);
      }
    });
  });

  testWidgets(
    'a locked ink, metro or unknown world keeps the unprinted outlines',
    (tester) async {
      await tester.runAsync(() async {
        final unprinted = await render('mystery', open: false);
        expect(await render('ink', open: false), unprinted);
        expect(await render('metro', open: false), unprinted);
      });
    },
  );

  testWidgets('painting is deterministic', (tester) async {
    await tester.runAsync(() async {
      for (final theme in newThemes) {
        expect(
          await render(theme, open: true),
          await render(theme, open: true),
          reason: theme,
        );
      }
    });
  });
}
