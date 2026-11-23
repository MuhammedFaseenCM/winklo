import 'package:flutter/painting.dart';

import '../../../../core/theme/app_theme.dart';
import 'ink_palette.dart';

/// One world theme's colours, shared by its backdrop, the line through its
/// levels and its level nodes, so a world can't drift apart. Ink and Metro
/// keep the colours they've always had; an unknown theme gets the plain
/// app look.
class LevelThemePalette {
  const LevelThemePalette({
    required this.base,
    this.baseEnd,
    required this.motif,
    required this.path,
    required this.pathWidth,
    required this.dots,
    required this.nodeFill,
    this.number = ZipColors.ink,
    this.lockedNumber = ZipColors.inkSoft,
  });

  /// The backdrop's ground; the top of a gradient when [baseEnd] is set.
  final Color base;

  /// The bottom of the ground's gradient, or null for a flat ground.
  final Color? baseEnd;

  /// The backdrop motif's lines and shapes (already faint).
  final Color motif;

  /// The line up to the current level.
  final Color path;
  final double pathWidth;

  /// The dotted road beyond the current level.
  final Color dots;

  /// A cleared level's disc, the current level's ring and the star marks.
  final Color nodeFill;

  /// A level's number on its disc.
  final Color number;

  /// A locked level's padlock.
  final Color lockedNumber;

  /// Every theme with its own look, in map order: Zip's, then Path
  /// Words' categories.
  static const themes = [
    'ink',
    'metro',
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

  static const plain = LevelThemePalette(
    base: ZipColors.ink,
    motif: Color(0x00000000),
    path: Color(0x99F8FAFC),
    pathWidth: 6,
    dots: ZipColors.outline,
    nodeFill: ZipColors.sky,
  );

  static LevelThemePalette of(String theme) => switch (theme) {
    'ink' => const LevelThemePalette(
      base: InkPalette.stone,
      motif: Color(0x4DC2410C),
      path: InkPalette.rice,
      pathWidth: 8,
      dots: InkPalette.pencil,
      nodeFill: InkPalette.rice,
      number: InkPalette.rice,
      lockedNumber: InkPalette.pencilLight,
    ),
    'metro' => const LevelThemePalette(
      base: Color(0xFF13233A),
      motif: Color(0x59F472B6),
      path: ZipColors.sky,
      pathWidth: 7,
      dots: ZipColors.outline,
      nodeFill: ZipColors.sky,
    ),
    // Zip's later worlds.
    'embroidery' => const LevelThemePalette(
      base: Color(0xFF1E2A44),
      baseEnd: Color(0xFF172036),
      motif: Color(0x38FCD34D),
      path: Color(0xFFFCD34D),
      pathWidth: 6,
      dots: Color(0xFF6B7A99),
      nodeFill: Color(0xFFFCD34D),
    ),
    'neon' => const LevelThemePalette(
      base: Color(0xFF0B0A16),
      baseEnd: Color(0xFF130A1F),
      motif: Color(0x66E879F9),
      path: Color(0xFFF0ABFC),
      pathWidth: 6,
      dots: Color(0xFF5B4A73),
      nodeFill: Color(0xFFF0ABFC),
    ),
    'sparkler' => const LevelThemePalette(
      base: Color(0xFF101A3A),
      baseEnd: Color(0xFF0B1128),
      motif: Color(0x59FDE68A),
      path: Color(0xFFFDE68A),
      pathWidth: 6,
      dots: Color(0xFF56628A),
      nodeFill: Color(0xFFFDE68A),
    ),
    // Path Words' categories.
    'animals' => const LevelThemePalette(
      base: Color(0xFF2B1733),
      baseEnd: Color(0xFF4A2414),
      motif: Color(0x33FDBA74),
      path: Color(0xFFFDBA74),
      pathWidth: 6,
      dots: Color(0xFF8A6A6F),
      nodeFill: Color(0xFFFDBA74),
    ),
    'food' => const LevelThemePalette(
      base: Color(0xFF3A1517),
      baseEnd: Color(0xFF2E1012),
      motif: Color(0x26FDE8D0),
      path: Color(0xFFFDE68A),
      pathWidth: 6,
      dots: Color(0xFF8C6466),
      nodeFill: Color(0xFFFDE68A),
    ),
    'sports' => const LevelThemePalette(
      base: Color(0xFF0E3B29),
      baseEnd: Color(0xFF0B2F21),
      motif: Color(0x40F8FAFC),
      path: Color(0xFFBEF264),
      pathWidth: 6,
      dots: Color(0xFF5E8A74),
      nodeFill: Color(0xFFBEF264),
    ),
    'nature' => const LevelThemePalette(
      base: Color(0xFF0B3A3A),
      baseEnd: Color(0xFF092C2E),
      motif: Color(0x405EEAD4),
      path: Color(0xFF5EEAD4),
      pathWidth: 6,
      dots: Color(0xFF4F807C),
      nodeFill: Color(0xFF5EEAD4),
    ),
    'home' => const LevelThemePalette(
      base: Color(0xFF2E2538),
      baseEnd: Color(0xFF241D2C),
      motif: Color(0x33E9D5FF),
      path: Color(0xFFFCD9A8),
      pathWidth: 6,
      dots: Color(0xFF7B6E8A),
      nodeFill: Color(0xFFFCD9A8),
    ),
    'body' => const LevelThemePalette(
      base: Color(0xFF3A1728),
      baseEnd: Color(0xFF2C111F),
      motif: Color(0x40FDA4AF),
      path: Color(0xFFFDA4AF),
      pathWidth: 6,
      dots: Color(0xFF8A5E6C),
      nodeFill: Color(0xFFFDA4AF),
    ),
    _ => plain,
  };
}
