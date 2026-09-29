import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'zip_path_ribbon.dart';

/// Soft ember flecks that orbit the live Zip stroke tip while drawing.
class ZipTipSparks {
  static const fleckCount = 8;

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
          speed: 1.2 + random.nextDouble() * 1.6,
          radiusFactor: 1.1 + random.nextDouble() * 0.5,
          size: 1.5 + random.nextDouble() * 2.0,
          color: Color.lerp(
            ZipColors.ember,
            ZipPathRibbon.colorAt(i),
            0.35 + random.nextDouble() * 0.45,
          )!.withValues(alpha: 0.35 + random.nextDouble() * 0.4),
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
    for (final fleck in _flecks) {
      final r = tipRadius * fleck.radiusFactor;
      final pos =
          tip + Offset(math.cos(fleck.angle) * r, math.sin(fleck.angle) * r);
      canvas.drawCircle(pos, fleck.size, Paint()..color = fleck.color);
    }
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
