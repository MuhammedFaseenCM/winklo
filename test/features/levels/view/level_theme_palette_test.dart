import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/levels/view/widgets/ink_palette.dart';
import 'package:winklo/features/levels/view/widgets/level_theme_palette.dart';
import 'package:winklo/features/levels/view/widgets/world_backdrop_painter.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('ink and metro keep today\'s colours', () {
    final ink = LevelThemePalette.of('ink');
    expect(ink.base, InkPalette.stone);
    expect(ink.path, InkPalette.rice);
    expect(ink.pathWidth, 8);
    expect(ink.dots, InkPalette.pencil);
    final metro = LevelThemePalette.of('metro');
    expect(metro.base, WorldBackdropPainter.metroNight);
    expect(metro.path, ZipColors.sky);
    expect(metro.pathWidth, 7);
    expect(metro.dots, ZipColors.outline);
    expect(metro.nodeFill, ZipColors.sky);
  });

  test('an unknown theme is the plain look', () {
    final plain = LevelThemePalette.of('x');
    expect(plain.base, ZipColors.ink);
    expect(plain.baseEnd, isNull);
    expect(plain.path, ZipColors.onInk.withValues(alpha: 0.6));
    expect(plain.pathWidth, 6);
    expect(plain.nodeFill, ZipColors.sky);
  });

  test('the new themes each have their own ground', () {
    final grounds = {
      for (final t in LevelThemePalette.themes)
        LevelThemePalette.of(t).base.toARGB32(),
    };
    expect(grounds.length, LevelThemePalette.themes.length);
    expect(grounds, isNot(contains(ZipColors.ink.toARGB32())));
  });

  test('every theme\'s path and node reach 3:1 against its ground', () {
    for (final theme in LevelThemePalette.themes) {
      final p = LevelThemePalette.of(theme);
      for (final ground in [p.base, ?p.baseEnd]) {
        expect(
          _contrast(p.path.withValues(alpha: 1), ground),
          greaterThanOrEqualTo(3),
          reason: '$theme path',
        );
        expect(
          _contrast(p.nodeFill, ground),
          greaterThanOrEqualTo(3),
          reason: '$theme node',
        );
      }
    }
  });
}
