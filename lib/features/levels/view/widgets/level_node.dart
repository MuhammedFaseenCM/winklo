import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/logic/level_map.dart';

/// One level on the map, drawn in its world's material: a brushed ensō on
/// Ink, a station on Metro. Cleared levels show their stars as marks
/// (vermilion seals on Ink, dots elsewhere); locked ones a padlock.
class LevelNode extends StatelessWidget {
  const LevelNode({super.key, required this.node, required this.onTap});

  final LevelMapNode node;
  final VoidCallback onTap;

  static const diameter = 40.0;
  static const width = 64.0;

  String get _label {
    final number = node.slot.number;
    return switch (node.state) {
      LevelNodeState.done => AppStrings.levelNodeDone(
        number,
        node.stars,
        node.maxStars,
      ),
      LevelNodeState.current => AppStrings.levelNodeCurrent(number),
      LevelNodeState.locked => AppStrings.levelNodeLocked(number),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = node.slot.world.theme;
    final locked = node.state == LevelNodeState.locked;
    final numberColor = switch ((theme, node.state)) {
      ('ink', LevelNodeState.locked) => const Color(0xFFA8A29E),
      ('ink', _) => const Color(0xFF111111),
      (_, LevelNodeState.locked) => ZipColors.inkSoft,
      _ => ZipColors.ink,
    };
    return Semantics(
      button: true,
      label: _label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: diameter,
                child: CustomPaint(
                  painter: _NodePainter(theme: theme, state: node.state),
                  child: Center(
                    child: locked
                        ? AppIcon(AppIcons.lock, size: 15, color: numberColor)
                        : Text(
                            '${node.slot.number}',
                            style: TextStyle(
                              color: numberColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (node.state == LevelNodeState.done)
                CustomPaint(
                  size: Size(node.maxStars * 10.0, 8),
                  painter: _StarMarksPainter(
                    theme: theme,
                    earned: node.stars,
                    total: node.maxStars,
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodePainter extends CustomPainter {
  _NodePainter({required this.theme, required this.state});

  final String theme;
  final LevelNodeState state;

  static const paper = Color(0xFFEFE8D8);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    if (theme == 'ink') {
      canvas.drawCircle(c, r, Paint()..color = paper);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      switch (state) {
        case LevelNodeState.done:
          // A brushed ensō: almost closed, the gap where the brush lifted.
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            -math.pi / 2 - 0.6,
            math.pi * 2 * 0.9,
            false,
            stroke
              ..strokeWidth = 3.4
              ..color = const Color(0xFF2B2724),
          );
        case LevelNodeState.current:
          canvas.drawCircle(
            c,
            r,
            stroke
              ..strokeWidth = 3.4
              ..color = const Color(0xFF111111),
          );
        case LevelNodeState.locked:
          canvas.drawCircle(
            c,
            r,
            stroke
              ..strokeWidth = 1.2
              ..color = const Color(0xFFA8A29E),
          );
      }
      return;
    }
    final fill = switch (state) {
      LevelNodeState.done => ZipColors.sky,
      LevelNodeState.current => ZipColors.onInk,
      LevelNodeState.locked => ZipColors.paper,
    };
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = state == LevelNodeState.current ? 3 : 1.5
        ..color = state == LevelNodeState.locked
            ? ZipColors.outline
            : ZipColors.sky,
    );
  }

  @override
  bool shouldRepaint(_NodePainter oldDelegate) =>
      oldDelegate.theme != theme || oldDelegate.state != state;
}

/// A level's stars in its world's material: vermilion seals on Ink, dots
/// elsewhere; filled when earned, outlined when not.
class _StarMarksPainter extends CustomPainter {
  _StarMarksPainter({
    required this.theme,
    required this.earned,
    required this.total,
  });

  final String theme;
  final int earned;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < total; i++) {
      final cx = 5.0 + i * 10;
      final on = i < earned;
      final paint = Paint()
        ..style = on ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1;
      if (theme == 'ink') {
        paint.color = const Color(0xFFB91C1C);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, 4), width: 7, height: 7),
            const Radius.circular(1.2),
          ),
          paint,
        );
      } else {
        paint.color = ZipColors.sky;
        canvas.drawCircle(Offset(cx, 4), 2.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StarMarksPainter oldDelegate) =>
      oldDelegate.earned != earned ||
      oldDelegate.total != total ||
      oldDelegate.theme != theme;
}
