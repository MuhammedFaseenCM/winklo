import 'package:flutter/painting.dart';

/// The Ink world's colours: ink-stone, a warm near-black ground, with a
/// vermilion grid and the line in rice-paper white. Dark like the rest of
/// the app, and still distinct from Metro's navy. Every Ink painter reads
/// these, so the world can't drift apart.
abstract final class InkPalette {
  /// The ground: backdrop, node discs, the star-mark patch.
  static const stone = Color(0xFF1C1915);

  /// The grid (drawn at [gridAlpha]).
  static const vermilion = Color(0xFFC2410C);
  static const gridAlpha = 0.30;

  /// The reached line, the current ring, the ensō and level numbers.
  static const rice = Color(0xFFEFE8D8);

  /// The unreached road and a locked level's ring.
  static const pencil = Color(0xFF78716C);

  /// A locked level's padlock.
  static const pencilLight = Color(0xFFA8A29E);

  /// Earned and unearned star seals.
  static const seal = Color(0xFFDC2626);
}
