enum LeaderboardPeriod { daily, allTime }

/// UTC calendar day key `yyyy-MM-dd` for daily leaderboard paths.
String utcLeaderboardDayId([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
