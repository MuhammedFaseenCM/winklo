import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/stats/best_trend.dart';

void main() {
  final today = DateTime(2026, 10, 15);

  test('no clears give an empty trend', () {
    expect(bestTrend(const {}, today: today), isEmpty);
  });

  test('only clears before the window give an empty trend', () {
    expect(bestTrend({DateTime(2026, 9, 1): 50}, today: today), isEmpty);
  });

  test('30 points, oldest first, across a month end', () {
    final trend = bestTrend({DateTime(2026, 10, 15): 70}, today: today);
    expect(trend, hasLength(30));
    expect(trend.first.day, DateTime(2026, 9, 16));
    expect(trend[14].day, DateTime(2026, 9, 30));
    expect(trend[15].day, DateTime(2026, 10, 1));
    expect(trend.last.day, today);
    expect(trend.last.seconds, 70);
    expect(trend.last.runningBest, 70);
    expect(trend.first.seconds, isNull);
    expect(trend.first.runningBest, isNull);
  });

  test('the running best carries the best from before the window', () {
    final trend = bestTrend({
      DateTime(2026, 8, 1): 40,
      DateTime(2026, 10, 10): 55,
    }, today: today);
    expect(trend.first.runningBest, 40);
    final oct10 = trend.firstWhere((p) => p.day == DateTime(2026, 10, 10));
    expect(oct10.seconds, 55);
    expect(oct10.runningBest, 40);
  });

  test('the running best drops on a new best and holds over gaps', () {
    final trend = bestTrend({
      DateTime(2026, 10, 1): 90,
      DateTime(2026, 10, 3): 120,
      DateTime(2026, 10, 5): 60,
      DateTime(2026, 10, 9): 75,
    }, today: today);
    int? bestOn(int day) =>
        trend.firstWhere((p) => p.day == DateTime(2026, 10, day)).runningBest;
    expect(bestOn(1), 90);
    expect(bestOn(2), 90);
    expect(bestOn(3), 90);
    expect(bestOn(5), 60);
    expect(bestOn(9), 60);
    expect(bestOn(15), 60);
    expect(trend.where((p) => p.seconds != null).map((p) => p.seconds), [
      90,
      120,
      60,
      75,
    ]);
  });

  test('a clear dated after today is left out', () {
    final trend = bestTrend({
      DateTime(2026, 10, 14): 80,
      DateTime(2026, 10, 16): 10,
    }, today: today);
    expect(trend.last.day, today);
    expect(trend.last.runningBest, 80);
  });

  test('the window length can change', () {
    final trend = bestTrend({today: 30}, today: today, days: 7);
    expect(trend, hasLength(7));
    expect(trend.first.day, DateTime(2026, 10, 9));
  });
}
