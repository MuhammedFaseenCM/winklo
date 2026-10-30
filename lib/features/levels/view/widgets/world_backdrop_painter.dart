import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../logic/level_map_layout.dart';

/// Each world's backdrop: rice paper with a vermilion grid (Ink), a night
/// transit map (Metro), or, for a world not yet open, its outlines only
/// ("unprinted"). An unknown theme gets the plain app background.
class WorldBackdropPainter extends CustomPainter {
  WorldBackdropPainter(this.bands);

  final List<LevelMapBand> bands;

  static const paper = Color(0xFFEFE8D8);
  static const vermilion = Color(0xFFC2410C);
  static const metroNight = Color(0xFF13233A);

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in bands) {
      final rect = band.rect;
      if (!band.world.open) {
        _unprinted(canvas, rect);
        continue;
      }
      switch (band.world.world.theme) {
        case 'ink':
          _ink(canvas, rect);
        case 'metro':
          _metro(canvas, rect);
        default:
          canvas.drawRect(rect, Paint()..color = ZipColors.ink);
      }
    }
  }

  void _ink(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = paper);
    final grid = Paint()
      ..color = vermilion.withValues(alpha: 0.28)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 4; i++) {
      final x = r.left + r.width * i / 4;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), grid);
    }
    for (var y = r.bottom - 70; y > r.top; y -= 70) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
    }
  }

  void _metro(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = metroNight);
    for (final (path, color) in _metroLines(r)) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.35),
      );
    }
  }

  void _unprinted(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = ZipColors.ink);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..color = ZipColors.outlineQuiet
      ..strokeWidth = 1;
    for (final (path, _) in _metroLines(r)) {
      final dashes = Path();
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 7) {
          dashes.addPath(
            metric.extractPath(d, math.min(d + 3, metric.length)),
            Offset.zero,
          );
        }
      }
      canvas.drawPath(dashes, dash);
    }
  }

  /// Three transit lines across [r]: the Metro look, and the outline of
  /// any world before it's printed.
  static List<(Path, Color)> _metroLines(Rect r) {
    final w = r.width;
    final h = r.height;
    return [
      (
        Path()
          ..moveTo(r.left + w * 0.12, r.bottom)
          ..lineTo(r.left + w * 0.12, r.top),
        const Color(0xFFF472B6),
      ),
      (
        Path()
          ..moveTo(r.left, r.top + h * 0.4)
          ..lineTo(r.left + w * 0.3, r.top + h * 0.4)
          ..lineTo(r.left + w * 0.38, r.top + h * 0.4 - w * 0.08)
          ..lineTo(r.right, r.top + h * 0.4 - w * 0.08),
        const Color(0xFFA3E635),
      ),
      (
        Path()
          ..moveTo(r.left + w * 0.86, r.top)
          ..lineTo(r.left + w * 0.86, r.top + h * 0.3)
          ..lineTo(r.left + w * 0.94, r.top + h * 0.3 + w * 0.08)
          ..lineTo(r.left + w * 0.94, r.bottom),
        const Color(0xFFFBBF24),
      ),
    ];
  }

  @override
  bool shouldRepaint(WorldBackdropPainter oldDelegate) =>
      !identical(oldDelegate.bands, bands);
}
