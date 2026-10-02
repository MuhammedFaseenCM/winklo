/// Device-local calendar helpers for daily puzzle / streak / leaderboard keys.
///
/// Always converts through [DateTime.toLocal] before reading Y/M/D so UTC
/// instants (and test clocks) map to the player's local calendar day.
abstract final class AppCalendar {
  static DateTime localWallClock(DateTime instant) => instant.toLocal();

  static DateTime calendarDay(DateTime instant) {
    final local = localWallClock(instant);
    return DateTime(local.year, local.month, local.day);
  }

  static String dateIdCompact(DateTime instant) {
    final local = localWallClock(instant);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String dateIdDashed(DateTime instant) {
    final local = localWallClock(instant);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
