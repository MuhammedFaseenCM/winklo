import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/logic/level_map.dart';
import '../../logic/level_map_layout.dart';

/// The line through the levels: drawn in the world's material up to the
/// current level (sumi ink on paper, a sky route on Metro), and a dotted
/// pencil road beyond it. Where it crosses into the next world it changes
/// to that world's material at the edge.
class LevelPathPainter extends CustomPainter {
  LevelPathPainter(this.layout);

  final LevelMapLayout layout;

  static const ink = Color(0xFF2B2724);
  static const pencil = Color(0xFFA8A29E);

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = layout.nodes;
    for (var i = 0; i + 1 < nodes.length; i++) {
      final a = layout.centers[nodes[i].slot.entry.id]!;
      final b = layout.centers[nodes[i + 1].slot.entry.id]!;
      final midY = (a.dy + b.dy) / 2;
      final segment = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final reached = nodes[i + 1].state != LevelNodeState.locked;
      final top = math.min(a.dy, b.dy);
      final bottom = math.max(a.dy, b.dy);
      for (final band in layout.bands) {
        if (band.rect.bottom < top || band.rect.top > bottom) continue;
        canvas.save();
        canvas.clipRect(band.rect);
        final theme = band.world.world.theme;
        if (reached) {
          canvas.drawPath(
            segment,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = switch (theme) {
                'ink' => 8,
                'metro' => 7,
                _ => 6,
              }
              ..color = switch (theme) {
                'ink' => ink,
                'metro' => ZipColors.sky,
                _ => ZipColors.onInk.withValues(alpha: 0.6),
              },
          );
        } else {
          final dots = Path();
          for (final metric in segment.computeMetrics()) {
            for (var d = 0.0; d < metric.length; d += 7) {
              dots.addPath(
                metric.extractPath(d, math.min(d + 2.2, metric.length)),
                Offset.zero,
              );
            }
          }
          canvas.drawPath(
            dots,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 1.6
              ..color = theme == 'ink' ? pencil : ZipColors.outline,
          );
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(LevelPathPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
