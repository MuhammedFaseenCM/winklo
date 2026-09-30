import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/cell.dart';
import '../../domain/entities/wall.dart';
import '../theme/app_theme.dart';

/// One fully-drawn completed path on a tutorial mini board.
typedef TutorialCompletedPath = ({List<Cell> cells, Color color});

/// Shared mini grid used by canned game tutorials (not the live puzzle).
class TutorialMiniBoard extends StatelessWidget {
  const TutorialMiniBoard({
    super.key,
    required this.size,
    required this.labels,
    required this.path,
    required this.pathProgress,
    this.walls = const [],
    this.highlightCells = const {},
    this.highlightPulse = 1,
    this.drawnFill = false,
    this.pathColor = ZipColors.ember,
    this.showFinger = true,
    this.fingerLifted = false,
    this.boardColor = ZipColors.paper,
    this.startMarkers = const {},
    this.startMarkerColor = ZipColors.sky,
    this.lockedCells = const {},
    this.completedPaths = const [],
  });

  final int size;
  final Map<Cell, String> labels;
  final List<Cell> path;
  final double pathProgress;
  final List<Wall> walls;
  final Set<Cell> highlightCells;
  final double highlightPulse;
  final bool drawnFill;
  final Color pathColor;
  final bool showFinger;
  final bool fingerLifted;
  final Color boardColor;
  final Set<Cell> startMarkers;
  final Color startMarkerColor;
  final Set<Cell> lockedCells;
  final List<TutorialCompletedPath> completedPaths;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: boardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZipColors.outlineQuiet),
        ),
        child: CustomPaint(
          painter: _TutorialMiniBoardPainter(
            size: size,
            labels: labels,
            path: path,
            pathProgress: pathProgress.clamp(0.0, 1.0),
            walls: walls,
            highlightCells: highlightCells,
            highlightPulse: highlightPulse.clamp(0.0, 1.0),
            drawnFill: drawnFill,
            pathColor: pathColor,
            showFinger: showFinger,
            fingerLifted: fingerLifted,
            startMarkers: startMarkers,
            startMarkerColor: startMarkerColor,
            lockedCells: lockedCells,
            completedPaths: completedPaths,
          ),
        ),
      ),
    );
  }
}

class _TutorialMiniBoardPainter extends CustomPainter {
  _TutorialMiniBoardPainter({
    required this.size,
    required this.labels,
    required this.path,
    required this.pathProgress,
    required this.walls,
    required this.highlightCells,
    required this.highlightPulse,
    required this.drawnFill,
    required this.pathColor,
    required this.showFinger,
    required this.fingerLifted,
    required this.startMarkers,
    required this.startMarkerColor,
    required this.lockedCells,
    required this.completedPaths,
  });

  final int size;
  final Map<Cell, String> labels;
  final List<Cell> path;
  final double pathProgress;
  final List<Wall> walls;
  final Set<Cell> highlightCells;
  final double highlightPulse;
  final bool drawnFill;
  final Color pathColor;
  final bool showFinger;
  final bool fingerLifted;
  final Set<Cell> startMarkers;
  final Color startMarkerColor;
  final Set<Cell> lockedCells;
  final List<TutorialCompletedPath> completedPaths;

  Color? _completedFillColor(Cell cell) {
    for (final completed in completedPaths) {
      if (completed.cells.contains(cell)) {
        return completed.color.withValues(alpha: 0.28);
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size boardSize) {
    final cellW = boardSize.width / size;
    final cellH = boardSize.height / size;
    final inset = math.min(cellW, cellH) * 0.08;
    final cellMin = math.min(cellW, cellH);

    Offset centerOf(Cell cell) =>
        Offset((cell.col + 0.5) * cellW, (cell.row + 0.5) * cellH);

    final visibleCount = path.isEmpty
        ? 0
        : math.max(1, (pathProgress * path.length).ceil());
    final visiblePath = path.isEmpty
        ? const <Cell>[]
        : path.take(visibleCount.clamp(0, path.length)).toList();
    final filled = drawnFill ? visiblePath.toSet() : const <Cell>{};

    final gridPaint = Paint()
      ..color = ZipColors.outlineQuiet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final cell = Cell(r, c);
        final rect = Rect.fromLTWH(
          c * cellW + inset,
          r * cellH + inset,
          cellW - inset * 2,
          cellH - inset * 2,
        );

        final completedColor = _completedFillColor(cell);
        final Color fillColor;
        if (completedColor != null) {
          fillColor = completedColor;
        } else if (lockedCells.contains(cell)) {
          fillColor = ZipColors.inkSoft.withValues(alpha: 0.22);
        } else if (filled.contains(cell)) {
          fillColor = pathColor.withValues(alpha: 0.28);
        } else {
          fillColor = ZipColors.wall;
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()..color = fillColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          gridPaint,
        );

        if (highlightCells.contains(cell) && highlightPulse > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()
              ..color = pathColor.withValues(alpha: 0.35 * highlightPulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }

        final label = labels[cell];
        if (label != null && label.isNotEmpty) {
          final locked = lockedCells.contains(cell);
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                color: ZipColors.onInk.withValues(alpha: locked ? 0.45 : 1),
                fontWeight: FontWeight.w800,
                fontSize: cellMin * 0.38,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            centerOf(cell) - Offset(tp.width / 2, tp.height / 2),
          );
        }
      }
    }

    final wallPaint = Paint()
      ..color = ZipColors.onInk
      ..strokeWidth = cellMin * 0.12
      ..strokeCap = StrokeCap.round;
    for (final wall in walls) {
      final a = centerOf(wall.a);
      final b = centerOf(wall.b);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      final normal = Offset(-dir.dy / len, dir.dx / len);
      final half = cellMin * 0.28;
      canvas.drawLine(mid - normal * half, mid + normal * half, wallPaint);
    }

    for (final completed in completedPaths) {
      _drawFullPath(
        canvas,
        centerOf,
        completed.cells,
        completed.color,
        cellMin,
      );
    }

    if (visiblePath.length >= 2) {
      _drawPartialPath(
        canvas,
        centerOf,
        path,
        visiblePath,
        visibleCount,
        pathProgress,
        pathColor,
        cellMin,
      );
    } else if (visiblePath.length == 1 && pathProgress > 0) {
      // Single-cell start: no stroke yet.
    }

    for (final marker in startMarkers) {
      _drawStartRing(canvas, centerOf(marker), cellMin, startMarkerColor);
    }

    if (showFinger && path.isNotEmpty && pathProgress > 0) {
      final fingerPos = _fingerPosition(centerOf);
      _drawFinger(canvas, fingerPos, cellMin);
    }
  }

  void _drawFullPath(
    Canvas canvas,
    Offset Function(Cell) centerOf,
    List<Cell> cells,
    Color color,
    double cellMin,
  ) {
    if (cells.length < 2) return;
    final pathPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellMin * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final uiPath = ui.Path()
      ..moveTo(centerOf(cells.first).dx, centerOf(cells.first).dy);
    for (var i = 1; i < cells.length; i++) {
      final p = centerOf(cells[i]);
      uiPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(uiPath, pathPaint);
  }

  void _drawPartialPath(
    Canvas canvas,
    Offset Function(Cell) centerOf,
    List<Cell> fullPath,
    List<Cell> visiblePath,
    int visibleCount,
    double progress,
    Color color,
    double cellMin,
  ) {
    final pathPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellMin * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final uiPath = ui.Path()
      ..moveTo(centerOf(visiblePath.first).dx, centerOf(visiblePath.first).dy);
    for (var i = 1; i < visiblePath.length; i++) {
      final p = centerOf(visiblePath[i]);
      uiPath.lineTo(p.dx, p.dy);
    }
    if (visibleCount < fullPath.length && visiblePath.isNotEmpty) {
      final from = centerOf(visiblePath.last);
      final to = centerOf(fullPath[visibleCount]);
      final frac = (progress * fullPath.length) - (visibleCount - 1);
      final t = frac.clamp(0.0, 1.0);
      uiPath.lineTo(
        ui.lerpDouble(from.dx, to.dx, t)!,
        ui.lerpDouble(from.dy, to.dy, t)!,
      );
    }
    canvas.drawPath(uiPath, pathPaint);
  }

  void _drawStartRing(
    Canvas canvas,
    Offset center,
    double cellMin,
    Color color,
  ) {
    final radius = cellMin * 0.34;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, cellMin * 0.07),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, cellMin * 0.035),
    );
  }

  Offset _fingerPosition(Offset Function(Cell) centerOf) {
    if (path.length == 1) return centerOf(path.first);
    final exact = pathProgress * (path.length - 1);
    final i = exact.floor().clamp(0, path.length - 2);
    final t = exact - i;
    final a = centerOf(path[i]);
    final b = centerOf(path[i + 1]);
    final base = Offset(
      ui.lerpDouble(a.dx, b.dx, t)!,
      ui.lerpDouble(a.dy, b.dy, t)!,
    );
    if (!fingerLifted) return base;
    return base.translate(0, -math.min(24.0, (a - b).distance * 0.4));
  }

  void _drawFinger(Canvas canvas, Offset pos, double cellMin) {
    final r = cellMin * 0.22;
    canvas.drawCircle(
      pos,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = ZipColors.ink.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      pos.translate(r * 0.55, r * 1.1),
      r * 0.55,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _TutorialMiniBoardPainter oldDelegate) {
    return oldDelegate.pathProgress != pathProgress ||
        oldDelegate.highlightPulse != highlightPulse ||
        oldDelegate.fingerLifted != fingerLifted ||
        oldDelegate.showFinger != showFinger ||
        oldDelegate.drawnFill != drawnFill ||
        oldDelegate.pathColor != pathColor ||
        oldDelegate.size != size ||
        oldDelegate.path != path ||
        oldDelegate.labels != labels ||
        oldDelegate.walls != walls ||
        oldDelegate.highlightCells != highlightCells ||
        oldDelegate.startMarkers != startMarkers ||
        oldDelegate.startMarkerColor != startMarkerColor ||
        oldDelegate.lockedCells != lockedCells ||
        oldDelegate.completedPaths != completedPaths;
  }
}
