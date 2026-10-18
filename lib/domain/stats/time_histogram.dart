/// One bar of the clear-time histogram: clears with
/// `fromSeconds <= time < toSeconds` (no upper bound when [toSeconds] is
/// null).
class HistogramBucket {
  const HistogramBucket({
    required this.fromSeconds,
    required this.toSeconds,
    required this.count,
  });

  final int fromSeconds;

  /// Exclusive; null for the open-ended last bucket.
  final int? toSeconds;

  final int count;

  @override
  bool operator ==(Object other) =>
      other is HistogramBucket &&
      other.fromSeconds == fromSeconds &&
      other.toSeconds == toSeconds &&
      other.count == count;

  @override
  int get hashCode => Object.hash(fromSeconds, toSeconds, count);

  @override
  String toString() => 'HistogramBucket($fromSeconds..$toSeconds: $count)';
}

/// Bucket widths that read well on a clock ("0:30–1:00", "2:00–4:00").
const _niceSteps = [
  5,
  10,
  15,
  20,
  30,
  60,
  90,
  120,
  180,
  300,
  600,
  900,
  1800,
  3600,
];

/// Splits clear [times] (seconds) into [buckets] bars of one "nice" width.
///
/// The width is the smallest nice step for which the closed bars (all but
/// the last) reach past the 90th percentile, starting at a multiple of the
/// step at or below the fastest time. The last bar is open-ended, so one slow
/// outlier lands there instead of flattening the chart. Empty for no times.
List<HistogramBucket> timeHistogram(Iterable<int> times, {int buckets = 5}) {
  final sorted = [for (final t in times) t < 0 ? 0 : t]..sort();
  if (sorted.isEmpty || buckets < 2) return const [];

  final closed = buckets - 1;
  final fastest = sorted.first;
  final high = sorted[((sorted.length - 1) * 9) ~/ 10];

  int startFor(int step) => (fastest ~/ step) * step;
  var step = _niceSteps.firstWhere(
    (s) => startFor(s) + closed * s > high,
    orElse: () => 0,
  );
  if (step == 0) {
    // Beyond an hour per bar: whole hours.
    step = 3600 * ((high ~/ closed) ~/ 3600 + 1);
    while (startFor(step) + closed * step <= high) {
      step += 3600;
    }
  }
  final start = startFor(step);

  final counts = List<int>.filled(buckets, 0);
  for (final t in sorted) {
    final index = (t - start) ~/ step;
    counts[index < closed ? index : closed]++;
  }
  return [
    for (var i = 0; i < buckets; i++)
      HistogramBucket(
        fromSeconds: start + i * step,
        toSeconds: i < closed ? start + (i + 1) * step : null,
        count: counts[i],
      ),
  ];
}
