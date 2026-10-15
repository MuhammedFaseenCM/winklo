import '../entities/game_day_record.dart';
import '../entities/game_streak.dart';
import 'best_trend.dart';
import 'clear_calendar.dart';
import 'clear_days.dart';
import 'time_histogram.dart';

/// Everything the stats screen shows for one game.
class GameStats {
  const GameStats({
    required this.gameId,
    required this.clears,
    required this.currentStreak,
    required this.longestStreak,
    required this.bestSeconds,
    required this.averageSeconds,
    required this.hintFreeShare,
    required this.histogram,
    required this.calendar,
    required this.trend,
  });

  final String gameId;
  final int clears;
  final int currentStreak;
  final int longestStreak;
  final int? bestSeconds;

  /// Mean clear time, rounded to the second.
  final int? averageSeconds;

  /// Share (0–1) of clears made without hints; null with no clears.
  final double? hintFreeShare;

  final List<HistogramBucket> histogram;
  final List<ClearCalendarMonth> calendar;
  final List<TrendPoint> trend;
}

/// Stats for [gameId] from its cleared [days] (other games' records and
/// uncleared days are ignored) and its stored [streak], already decayed for
/// [today].
///
/// The current streak is the stored one (as Home shows it, freezes
/// included). The longest is the larger of the stored longest and the longest
/// run of consecutive cleared days.
GameStats computeGameStats({
  required String gameId,
  required Iterable<GameDayRecord> days,
  required GameStreak streak,
  required DateTime today,
}) {
  final clears = [
    for (final day in days)
      if (day.gameId == gameId && day.cleared) day,
  ];
  final times = [for (final day in clears) day.timeSeconds!];
  final byDate = bestTimeByDate(clears);
  final run = longestDailyRun(byDate.keys);

  int? best;
  var total = 0;
  for (final t in times) {
    total += t;
    if (best == null || t < best) best = t;
  }

  return GameStats(
    gameId: gameId,
    clears: clears.length,
    currentStreak: streak.current,
    longestStreak: streak.longest > run ? streak.longest : run,
    bestSeconds: best,
    averageSeconds: times.isEmpty ? null : (total / times.length).round(),
    hintFreeShare: clears.isEmpty
        ? null
        : clears.where(isHintFree).length / clears.length,
    histogram: timeHistogram(times),
    calendar: clearCalendar(byDate.keys, today: today),
    trend: bestTrend(byDate, today: today),
  );
}
