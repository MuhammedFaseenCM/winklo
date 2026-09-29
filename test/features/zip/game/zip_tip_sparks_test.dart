import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/features/zip/game/zip_tip_sparks.dart';

void main() {
  test('starts inactive with zero flecks', () {
    final sparks = ZipTipSparks();
    expect(sparks.isActive, isFalse);
    expect(sparks.count, 0);
  });

  test('ensureActive spawns a fixed fleck set', () {
    final sparks = ZipTipSparks();
    sparks.ensureActive(seed: 7);
    expect(sparks.isActive, isTrue);
    expect(sparks.count, ZipTipSparks.fleckCount);
    sparks.ensureActive(seed: 99);
    expect(sparks.count, ZipTipSparks.fleckCount);
  });

  test('clear empties flecks immediately', () {
    final sparks = ZipTipSparks()..ensureActive(seed: 1);
    sparks.clear();
    expect(sparks.isActive, isFalse);
    expect(sparks.count, 0);
  });

  test('update advances angles without changing count', () {
    final sparks = ZipTipSparks()..ensureActive(seed: 3);
    final before = sparks.debugAngles();
    sparks.update(1 / 60);
    final after = sparks.debugAngles();
    expect(sparks.count, ZipTipSparks.fleckCount);
    expect(after, isNot(before));
  });

  test('paint is a no-op when inactive', () {
    final sparks = ZipTipSparks();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    sparks.paint(canvas, tip: Offset.zero, tipRadius: 10);
    expect(sparks.isActive, isFalse);
    expect(sparks.count, 0);
  });
}
