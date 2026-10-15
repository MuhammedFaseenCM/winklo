import 'clear_days.dart';

/// One day of the personal-best trend.
class TrendPoint {
  const TrendPoint({required this.day, this.seconds, this.runningBest});

  /// Local date (midnight).
  final DateTime day;

  /// That day's clear time; null when the day wasn't cleared.
  final int? seconds;

  /// Best clear time on or before [day] (all time); null before the first
  /// clear.
  final int? runningBest;

  @override
  bool operator ==(Object other) =>
      other is TrendPoint &&
      other.day == day &&
      other.seconds == seconds &&
      other.runningBest == runningBest;

  @override
  int get hashCode => Object.hash(day, seconds, runningBest);

  @override
  String toString() => 'TrendPoint($day, $seconds, best: $runningBest)';
}

/// The last [days] days up to [today] (oldest first), each with its clear
/// time from [timeByDate] and the running all-time best as of that day.
/// Empty when no day in the window was cleared.
List<TrendPoint> bestTrend(
  Map<DateTime, int> timeByDate, {
  required DateTime today,
  int days = 30,
}) {
  final first = addDays(today, -(days - 1));
  final window = [for (var i = 0; i < days; i++) addDays(first, i)];
  if (!window.any(timeByDate.containsKey)) return const [];

  int? best;
  for (final MapEntry(key: day, value: time) in timeByDate.entries) {
    if (day.isBefore(first) && (best == null || time < best)) best = time;
  }
  final points = <TrendPoint>[];
  for (final day in window) {
    final time = timeByDate[day];
    if (time != null && (best == null || time < best)) best = time;
    points.add(TrendPoint(day: day, seconds: time, runningBest: best));
  }
  return points;
}
