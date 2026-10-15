import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/stats/time_histogram.dart';

List<(int, int?, int)> _shape(List<HistogramBucket> buckets) => [
  for (final b in buckets) (b.fromSeconds, b.toSeconds, b.count),
];

void main() {
  test('no times give no buckets', () {
    expect(timeHistogram(const []), isEmpty);
  });

  test('one time lands in the first of five buckets', () {
    final buckets = timeHistogram([42]);
    expect(_shape(buckets), [
      (40, 45, 1),
      (45, 50, 0),
      (50, 55, 0),
      (55, 60, 0),
      (60, null, 0),
    ]);
  });

  test('all equal times share one bucket', () {
    final buckets = timeHistogram([90, 90, 90]);
    expect(buckets.first.count, 3);
    expect(buckets.skip(1).every((b) => b.count == 0), isTrue);
  });

  test('buckets use a nice step and hold every clear', () {
    final times = [35, 48, 52, 61, 66, 74, 80, 95, 110, 118];
    final buckets = timeHistogram(times);
    expect(buckets, hasLength(5));
    expect(_shape(buckets), [
      (30, 60, 3),
      (60, 90, 4),
      (90, 120, 3),
      (120, 150, 0),
      (150, null, 0),
    ]);
    expect(buckets.fold<int>(0, (sum, b) => sum + b.count), times.length);
  });

  test('a slow outlier lands in the open last bucket', () {
    final times = [40, 45, 50, 55, 58, 60, 62, 65, 70, 1500];
    final buckets = timeHistogram(times);
    expect(buckets.last.toSeconds, isNull);
    expect(buckets.last.count, 1);
    // The step follows the bulk of the clears, not the outlier.
    expect(buckets.first.toSeconds! - buckets.first.fromSeconds, 10);
    expect(buckets.fold<int>(0, (sum, b) => sum + b.count), times.length);
  });

  test('a time on a boundary goes to the upper bucket', () {
    final buckets = timeHistogram([30, 40, 41, 49]);
    expect(_shape(buckets), [
      (30, 35, 1),
      (35, 40, 0),
      (40, 45, 2),
      (45, 50, 1),
      (50, null, 0),
    ]);
  });

  test('long clears use minute steps', () {
    final buckets = timeHistogram([300, 420, 600, 840, 900]);
    expect(_shape(buckets), [
      (180, 360, 1),
      (360, 540, 1),
      (540, 720, 1),
      (720, 900, 1),
      (900, null, 1),
    ]);
  });

  test('very long clears still fit', () {
    final buckets = timeHistogram([10, 20000]);
    expect(buckets, hasLength(5));
    expect(buckets.fold<int>(0, (sum, b) => sum + b.count), 2);
    expect(buckets.last.fromSeconds, lessThanOrEqualTo(20000));
  });

  test('zero-second clears count', () {
    final buckets = timeHistogram([0, 3]);
    expect(_shape(buckets).first, (0, 5, 2));
  });
}
