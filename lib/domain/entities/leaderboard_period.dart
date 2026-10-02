import '../app_calendar.dart';

enum LeaderboardPeriod { daily, allTime }

/// Device-local calendar day key `yyyy-MM-dd` for daily leaderboard paths.
String leaderboardDayId([DateTime? now]) {
  return AppCalendar.dateIdDashed(now ?? DateTime.now());
}
