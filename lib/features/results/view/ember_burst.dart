import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One-shot ember spark burst around the center of its box.
class EmberBurst extends StatefulWidget {
  const EmberBurst({
    super.key,
    this.duration = const Duration(milliseconds: 750),
    this.particleCount = 18,
  });

  final Duration duration;
  final int particleCount;

  @override
  State<EmberBurst> createState() => _EmberBurstState();
}

class _EmberBurstState extends State<EmberBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    final random = math.Random(7);
    _sparks = List.generate(widget.particleCount, (i) {
      final angle =
          (i / widget.particleCount) * math.pi * 2 + random.nextDouble() * 0.35;
      return _Spark(
        angle: angle,
        distance: 28 + random.nextDouble() * 46,
        size: 2.5 + random.nextDouble() * 3.5,
        hueShift: random.nextDouble(),
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _EmberBurstPainter(
              progress: Curves.easeOutCubic.transform(_controller.value),
              sparks: _sparks,
            ),
          );
        },
      ),
    );
  }
}

class _Spark {
  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
    required this.hueShift,
  });

  final double angle;
  final double distance;
  final double size;
  final double hueShift;
}

class _EmberBurstPainter extends CustomPainter {
  _EmberBurstPainter({required this.progress, required this.sparks});

  final double progress;
  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (final spark in sparks) {
      final radius = spark.distance * progress;
      final offset = Offset(
        center.dx + math.cos(spark.angle) * radius,
        center.dy + math.sin(spark.angle) * radius,
      );
      final color = Color.lerp(
        ZipColors.ember,
        ZipColors.onInk,
        spark.hueShift * 0.35,
      )!.withValues(alpha: fade);
      canvas.drawCircle(
        offset,
        spark.size * (0.6 + 0.4 * (1 - progress)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmberBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
