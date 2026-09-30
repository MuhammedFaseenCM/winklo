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
    space(isCompact ? 16 : 24),
    space(isCompact ? 16 : 28),
    space(isCompact ? 16 : 24),
    space(isCompact ? 24 : 32),
  );

  double get sectionGap => space(isCompact ? 18 : 28);

  double get tileGap => space(isCompact ? 12 : 16);

  double get headerMarkSize => space(isCompact ? 44 : 56);

  EdgeInsets get tilePadding => EdgeInsets.all(space(isCompact ? 14 : 18));

  double get tileArtSize => space(isCompact ? 52 : 64);

  EdgeInsets get buttonPadding => EdgeInsets.symmetric(
    horizontal: space(isCompact ? 16 : 22),
    vertical: space(isCompact ? 12 : 16),
  );
}
