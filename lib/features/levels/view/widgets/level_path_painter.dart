import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../domain/logic/level_map.dart';
import '../../logic/level_map_layout.dart';
import 'level_theme_palette.dart';

/// The line through the levels: drawn in the world's material up to the
/// current level (rice-paper white on ink-stone, a sky route on Metro), and
/// a dotted pencil road beyond it. Where it crosses into the next world it
/// changes to that world's material at the edge.
class LevelPathPainter extends CustomPainter {
  LevelPathPainter(this.layout);

  final LevelMapLayout layout;

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
        final palette = LevelThemePalette.of(band.world.world.theme);
        if (reached) {
          canvas.drawPath(
            segment,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = palette.pathWidth
              ..color = palette.path,
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
              ..color = palette.dots,
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
