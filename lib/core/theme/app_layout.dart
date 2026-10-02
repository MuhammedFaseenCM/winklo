import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Screen-driven spacing/scale for dense game UI.
///
/// Tuned to a phone reference of 390×844. Short/narrow devices tighten
/// padding so home cards (and CTAs) stay reachable without huge scroll.
@immutable
class AppLayout {
  const AppLayout({
    required this.size,
    required this.scale,
    required this.isCompact,
  });

  /// Reference phone used for spacing design.
  static const Size designSize = Size(390, 844);

  final Size size;

  /// Multiplier applied to designed spacing (clamped).
  final double scale;

  /// True on short or narrow screens that need denser chrome.
  final bool isCompact;

  factory AppLayout.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final widthScale = size.width / designSize.width;
    final heightScale = size.height / designSize.height;
    final scale = math.min(widthScale, heightScale).clamp(0.82, 1.05);
    final isCompact = size.height < 740 || size.width < 360;
    return AppLayout(size: size, scale: scale, isCompact: isCompact);
  }

  double space(double base) => base * scale;

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
    space(isCompact ? 16 : 20),
    space(isCompact ? 12 : 16),
    space(isCompact ? 16 : 20),
    space(isCompact ? 16 : 20),
  );

  double get sectionGap => space(isCompact ? 10 : 12);

  double get tileGap => space(isCompact ? 8 : 10);

  double get headerMarkSize => space(isCompact ? 40 : 48);

  EdgeInsets get tilePadding => EdgeInsets.fromLTRB(
    space(isCompact ? 10 : 12),
    space(isCompact ? 8 : 10),
    space(isCompact ? 10 : 12),
    space(isCompact ? 8 : 10),
  );

  double get tileArtSize => space(isCompact ? 44 : 52);

  /// Estimated tile height used to decide whether home needs a scroll fallback.
  double get homeMinTileHeight => isCompact ? 128 : 140;

  EdgeInsets get buttonPadding => EdgeInsets.symmetric(
    horizontal: space(isCompact ? 16 : 22),
    vertical: space(isCompact ? 12 : 16),
  );

  EdgeInsets get compactButtonPadding => EdgeInsets.symmetric(
    horizontal: space(isCompact ? 12 : 16),
    vertical: space(isCompact ? 10 : 12),
  );
}
