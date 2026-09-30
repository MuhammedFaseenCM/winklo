import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'zip_path_ribbon.dart';

/// Ember diamond twinkles that orbit the live Zip stroke tip while drawing.
class ZipTipSparks {
  static const fleckCount = 6;

  final List<_Fleck> _flecks = [];

  bool get isActive => _flecks.isNotEmpty;
  int get count => _flecks.length;

  /// Test-only angle snapshot.
  List<double> debugAngles() => [for (final f in _flecks) f.angle];

  void ensureActive({required int seed}) {
    if (_flecks.isNotEmpty) return;
    final random = math.Random(seed);
    for (var i = 0; i < fleckCount; i++) {
      final t = i / fleckCount;
      _flecks.add(
        _Fleck(
          angle: t * math.pi * 2 + random.nextDouble() * 0.4,
          speed: 1.0 + random.nextDouble() * 1.4,
          radiusFactor: 1.15 + random.nextDouble() * 0.45,
          size: 2.2 + random.nextDouble() * 1.8,
          color: Color.lerp(
            ZipColors.ember,
            ZipPathRibbon.colorAt(i),
            0.35 + random.nextDouble() * 0.45,
          )!.withValues(alpha: 0.55 + random.nextDouble() * 0.35),
        ),
      );
    }
  }

  void clear() => _flecks.clear();

  void update(double dt) {
    for (final fleck in _flecks) {
      fleck.angle += fleck.speed * dt;
    }
  }

  void paint(Canvas canvas, {required Offset tip, required double tipRadius}) {
    if (_flecks.isEmpty) return;
    final diamondPaint = Paint()..style = PaintingStyle.fill;
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final fleck in _flecks) {
      final r = tipRadius * fleck.radiusFactor;
      final pos =
          tip + Offset(math.cos(fleck.angle) * r, math.sin(fleck.angle) * r);
      _paintTwinkle(
        canvas,
        pos: pos,
        size: fleck.size,
        color: fleck.color,
        diamondPaint: diamondPaint,
        rayPaint: rayPaint,
      );
    }
  }

  static void _paintTwinkle(
    Canvas canvas, {
    required Offset pos,
    required double size,
    required Color color,
    required Paint diamondPaint,
    required Paint rayPaint,
  }) {
    final half = size * 0.55;
    final ray = size * 1.7;

    rayPaint
      ..color = Colors.white.withValues(alpha: color.a * 0.55)
      ..strokeWidth = math.max(0.8, size * 0.22);
    canvas.drawLine(
      Offset(pos.dx, pos.dy - ray),
      Offset(pos.dx, pos.dy + ray),
      rayPaint,
    );
    canvas.drawLine(
      Offset(pos.dx - ray, pos.dy),
      Offset(pos.dx + ray, pos.dy),
      rayPaint,
    );

    diamondPaint.color = color;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
      diamondPaint,
    );
    canvas.restore();
  }
}

class _Fleck {
  _Fleck({
    required this.angle,
    required this.speed,
    required this.radiusFactor,
    required this.size,
    required this.color,
  });

  double angle;
  final double speed;
  final double radiusFactor;
  final double size;
  final Color color;
}
