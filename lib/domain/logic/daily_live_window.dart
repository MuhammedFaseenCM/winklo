/// When a daily puzzle is live, as `daily_live.ts` decides it: from 10:00
/// UTC on the day before (when the first time zones reach the day) to 12:00
/// UTC on the day after (when the last ones leave it).
abstract final class DailyLiveWindow {
  /// When the puzzle for [day]'s calendar day goes live.
  static DateTime opensAt(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day - 1, 10);

  /// When the puzzle for [day]'s calendar day stops being live.
  static DateTime closesAt(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day + 1, 12);

  static bool isLive(DateTime day, DateTime at) {
    final t = at.toUtc();
    return !t.isBefore(opensAt(day)) && t.isBefore(closesAt(day));
  }
}
