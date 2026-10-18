import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/stats/best_trend.dart';

/// The last 30 days' clear times (dots, joined on consecutive days) and the
/// running personal best (a step line). Slower is higher.
class BestTrendChart extends StatelessWidget {
  const BestTrendChart({super.key, required this.points});

  final List<TrendPoint> points;

  static const height = 150.0;

  /// Two series, validated for the dark surface (lightness band, CVD).
  static const timesColor = Color(0xFF0B9BDB);
  static const bestColor = ZipColors.emberDeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final cleared = points.where((p) => p.seconds != null).length;
    final best = points.isEmpty ? null : points.last.runningBest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _LegendItem(
              label: AppStrings.statsTrendTimes,
              swatch: const _DotSwatch(color: timesColor),
              style: labelStyle,
            ),
            _LegendItem(
              label: AppStrings.statsTrendBest,
              swatch: const _LineSwatch(color: bestColor),
              style: labelStyle,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: AppStrings.statsTrendSemantics(
            clears: cleared,
            bestSeconds: best,
          ),
          excludeSemantics: true,
          child: CustomPaint(
            size: const Size(double.infinity, height),
            painter: BestTrendPainter(
              points: points,
              labelStyle: labelStyle,
              textScaler: MediaQuery.textScalerOf(context),
              firstLabel: points.isEmpty
                  ? ''
                  : localizations.formatShortMonthDay(points.first.day),
              lastLabel: AppStrings.statsTrendToday,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.swatch,
    required this.style,
  });

  final String label;
  final Widget swatch;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}

class _DotSwatch extends StatelessWidget {
  const _DotSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LineSwatch extends StatelessWidget {
  const _LineSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 2,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}

class BestTrendPainter extends CustomPainter {
  BestTrendPainter({
    required this.points,
    required this.labelStyle,
    required this.textScaler,
    required this.firstLabel,
    required this.lastLabel,
  });

  final List<TrendPoint> points;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final String firstLabel;
  final String lastLabel;

  static const _dotRadius = 4.0;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final p in points) ...[?p.seconds, ?p.runningBest],
    ];
    if (points.length < 2 || values.isEmpty) return;

    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    if (high - low < 10) {
      // A flat run still gets some room above and below.
      final mid = (high + low) / 2;
      low = math.max(0, (mid - 5).floor());
      high = (mid + 5).ceil();
    }
    final lowLabel = _text(AppStrings.formatPlayTime(low));
    final highLabel = _text(AppStrings.formatPlayTime(high));
    final first = _text(firstLabel);
    final last = _text(lastLabel);

    final gutter = math.max(lowLabel.width, highLabel.width) + 8;
    final plot = Rect.fromLTRB(
      gutter + _dotRadius,
      _dotRadius + 2,
      size.width - _dotRadius,
      size.height - first.height - 8,
    );
    double x(int i) => plot.left + plot.width * i / (points.length - 1);
    double y(int seconds) =>
        plot.bottom - plot.height * (seconds - low) / (high - low);

    final grid = Paint()
      ..color = ZipColors.outlineQuiet
      ..strokeWidth = 1;
    for (final (value, label) in [(high, highLabel), (low, lowLabel)]) {
      final gy = y(value);
      canvas.drawLine(Offset(plot.left, gy), Offset(plot.right, gy), grid);
      label.paint(canvas, Offset(0, gy - label.height / 2));
    }
    first.paint(canvas, Offset(plot.left - _dotRadius, plot.bottom + 8));
    last.paint(canvas, Offset(size.width - last.width, plot.bottom + 8));

    // Running best: a step line from the first day it exists.
    final bestPath = Path();
    var started = false;
    int? previousBest;
    for (var i = 0; i < points.length; i++) {
      final best = points[i].runningBest;
      if (best == null) continue;
      if (!started) {
        bestPath.moveTo(x(i), y(best));
        started = true;
      } else {
        bestPath.lineTo(x(i), y(previousBest!));
        if (best != previousBest) bestPath.lineTo(x(i), y(best));
      }
      previousBest = best;
    }
    canvas.drawPath(
      bestPath,
      Paint()
        ..color = BestTrendChart.bestColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Clear times: joined only across consecutive cleared days.
    final linePaint = Paint()
      ..color = BestTrendChart.timesColor.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1].seconds;
      final b = points[i].seconds;
      if (a == null || b == null) continue;
      canvas.drawLine(Offset(x(i - 1), y(a)), Offset(x(i), y(b)), linePaint);
    }
    final ring = Paint()..color = ZipColors.wall;
    final dot = Paint()..color = BestTrendChart.timesColor;
    for (var i = 0; i < points.length; i++) {
      final s = points[i].seconds;
      if (s == null) continue;
      final c = Offset(x(i), y(s));
      canvas.drawCircle(c, _dotRadius + 2, ring);
      canvas.drawCircle(c, _dotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(BestTrendPainter old) =>
      !listEquals(old.points, points) ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler ||
      old.firstLabel != firstLabel ||
      old.lastLabel != lastLabel;
}
