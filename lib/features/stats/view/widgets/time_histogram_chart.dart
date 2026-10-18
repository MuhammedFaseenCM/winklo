import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/stats/time_histogram.dart';

/// Bars of clear counts per time range, labelled with each range's lower
/// edge (the last, open-ended range reads "4:00+").
class TimeHistogramChart extends StatelessWidget {
  const TimeHistogramChart({super.key, required this.buckets});

  final List<HistogramBucket> buckets;

  static const height = 140.0;

  /// Single series: the darker ember step keeps the bars inside the dark
  /// chart lightness band.
  static const barColor = ZipColors.emberDeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final countStyle = theme.textTheme.labelMedium!.copyWith(
      color: ZipColors.onInk,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      label: [
        for (final b in buckets)
          AppStrings.statsTimesBucketSemantics(
            b.fromSeconds,
            b.toSeconds,
            b.count,
          ),
      ].join('; '),
      excludeSemantics: true,
      child: CustomPaint(
        size: const Size(double.infinity, height),
        painter: TimeHistogramPainter(
          buckets: buckets,
          labelStyle: labelStyle,
          countStyle: countStyle,
          textScaler: MediaQuery.textScalerOf(context),
        ),
      ),
    );
  }
}

class TimeHistogramPainter extends CustomPainter {
  TimeHistogramPainter({
    required this.buckets,
    required this.labelStyle,
    required this.countStyle,
    required this.textScaler,
  });

  final List<HistogramBucket> buckets;
  final TextStyle labelStyle;
  final TextStyle countStyle;
  final TextScaler textScaler;

  static const _gap = 6.0;
  static const _radius = Radius.circular(4);

  TextPainter _text(String text, TextStyle style, double maxWidth) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final slot = (size.width - _gap * (buckets.length - 1)) / buckets.length;
    final sampleLabel = _text('0:00', labelStyle, slot);
    final sampleCount = _text('0', countStyle, slot);
    final baseline = size.height - sampleLabel.height - 6;
    final top = sampleCount.height + 4;
    final maxCount = buckets.fold<int>(1, (m, b) => b.count > m ? b.count : m);

    canvas.drawLine(
      Offset(0, baseline + 0.5),
      Offset(size.width, baseline + 0.5),
      Paint()
        ..color = ZipColors.outlineQuiet
        ..strokeWidth = 1,
    );

    final barPaint = Paint()..color = TimeHistogramChart.barColor;
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final left = i * (slot + _gap);
      if (b.count > 0) {
        final h = (baseline - top) * b.count / maxCount;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(left, baseline - h, left + slot, baseline),
            topLeft: _radius,
            topRight: _radius,
          ),
          barPaint,
        );
        final count = _text('${b.count}', countStyle, slot);
        count.paint(
          canvas,
          Offset(
            left + (slot - count.width) / 2,
            baseline - h - count.height - 2,
          ),
        );
      }
      final label = _text(
        AppStrings.statsTimesBucket(b.fromSeconds, open: b.toSeconds == null),
        labelStyle,
        slot,
      );
      label.paint(
        canvas,
        Offset(left + (slot - label.width) / 2, baseline + 6),
      );
    }
  }

  @override
  bool shouldRepaint(TimeHistogramPainter old) =>
      !listEquals(old.buckets, buckets) ||
      old.labelStyle != labelStyle ||
      old.countStyle != countStyle ||
      old.textScaler != textScaler;
}
