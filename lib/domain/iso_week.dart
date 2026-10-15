/// The ISO 8601 week (`yyyy-Www`) holding the leaderboard day [dayId]
/// (`yyyy-MM-dd`).
///
/// Weeks start on Monday and week 1 holds the year's first Thursday, so early
/// January can belong to the previous year's last week. The Worker's copy is
/// `isoWeekId` in workers/leaderboard/src/days.ts; both are tested on the same
/// days.
String isoWeekIdForDayId(String dayId) {
  final parts = dayId.split('-');
  if (parts.length != 3) {
    throw ArgumentError.value(dayId, 'dayId', 'not yyyy-MM-dd');
  }
  final date = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  // The Thursday of this week decides the week-year.
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  final weekYear = thursday.year;
  final dayOfYear = thursday.difference(DateTime.utc(weekYear)).inDays;
  final week = dayOfYear ~/ 7 + 1;
  return '$weekYear-W${week.toString().padLeft(2, '0')}';
}
