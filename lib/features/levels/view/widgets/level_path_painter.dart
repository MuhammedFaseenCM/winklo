import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/logic/level_map.dart';
import '../../logic/level_map_layout.dart';

/// The line through the levels: drawn in the world's material up to the
/// current level (sumi ink on paper, a sky route on Metro), and a dotted
/// pencil road beyond it.
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
      final next = nodes[i + 1];
      final theme = next.slot.world.theme;
      if (next.state != LevelNodeState.locked) {
        canvas.drawPath(
          segment,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = theme == 'ink' ? 8 : 7
            ..color = switch (theme) {
              'ink' => ink,
              'metro' => ZipColors.sky,
              _ => ZipColors.onInk.withValues(alpha: 0.6),
            },
        );
      } else {
        final dot = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6
          ..color = theme == 'ink' ? pencil : ZipColors.outline;
        for (final metric in segment.computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 7) {
            canvas.drawPath(
              metric.extractPath(d, math.min(d + 2.2, metric.length)),
              dot,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(LevelPathPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
