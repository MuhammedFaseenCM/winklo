import 'app_calendar.dart';

/// Pure helpers for engagement notification times (device local). Times of
/// day are minutes after local midnight.
abstract final class EngagementNotificationSchedule {
  /// [dayOffset] days after [day]'s local date, at [minutes].
  static DateTime atMinutes(DateTime day, int minutes, {int dayOffset = 0}) {
    final local = AppCalendar.localWallClock(day);
    return DateTime(
      local.year,
      local.month,
      local.day + dayOffset,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  /// The next time the clock shows [minutes]: today if it is still ahead,
  /// otherwise tomorrow.
  static DateTime nextDailyAt(int minutes, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = atMinutes(clock, minutes);
    return today.isAfter(clock)
        ? today
        : atMinutes(clock, minutes, dayOffset: 1);
  }

  /// The next [weekday] (`DateTime.monday`…`DateTime.sunday`) at [minutes]:
  /// today when it is that day and the time is still ahead.
  static DateTime nextWeekdayAt(int weekday, int minutes, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final local = AppCalendar.localWallClock(clock);
    final ahead = (weekday - local.weekday) % DateTime.daysPerWeek;
    final candidate = atMinutes(clock, minutes, dayOffset: ahead);
    if (candidate.isAfter(clock)) return candidate;
    return atMinutes(clock, minutes, dayOffset: ahead + DateTime.daysPerWeek);
  }
}
