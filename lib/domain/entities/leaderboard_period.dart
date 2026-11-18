import '../app_calendar.dart';

enum LeaderboardPeriod {
  daily,

  /// This ISO week (Monday to Sunday) of the local day: days cleared, then
  /// total time. Only the leaderboard Worker writes it.
  weekly,
  allTime,

  /// Every level cleared, ranked by stars, then fewest levels, then total
  /// best time. One row per player; only the leaderboard Worker writes it.
  levels,
}

/// Device-local calendar day key `yyyy-MM-dd` for daily leaderboard paths.
String leaderboardDayId([DateTime? now]) {
  return AppCalendar.dateIdDashed(now ?? DateTime.now());
}

/// The last [count] leaderboard days, today (of [now]) first.
List<String> recentLeaderboardDayIds(DateTime now, {int count = 14}) {
  final local = now.toLocal();
  return [
    for (var i = 0; i < count; i++)
      leaderboardDayId(DateTime(local.year, local.month, local.day - i)),
  ];
}
