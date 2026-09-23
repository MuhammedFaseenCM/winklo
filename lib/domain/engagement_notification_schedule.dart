/// Pure helpers for engagement notification schedule times (device local).
abstract final class EngagementNotificationSchedule {
  /// Next local DateTime at [hour]:00 today, or tomorrow if that time has passed.
  static DateTime nextDailyAtHour(int hour, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final local = DateTime(clock.year, clock.month, clock.day, hour);
    if (!local.isAfter(clock)) {
      return local.add(const Duration(days: 1));
    }
    return local;
  }

  /// Whether to schedule streak-at-risk for today/tonight.
  /// True when at least one enabled game is still uncleared today.
  static bool shouldScheduleStreakAtRisk({
    required bool zipClearedToday,
    required bool pathWordsClearedToday,
  }) {
    return !(zipClearedToday && pathWordsClearedToday);
  }
}
