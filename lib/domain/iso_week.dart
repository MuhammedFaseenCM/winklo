/// The ISO 8601 week (`yyyy-Www`) holding the leaderboard day [dayId]
/// (`yyyy-MM-dd`).
///
/// Weeks start on Monday and week 1 holds the year's first Thursday, so early
/// January can belong to the previous year's last week. The Worker's copy is
/// `isoWeekId` in workers/leaderboard/src/days.ts; both are tested on the same
/// days.
String isoWeekIdForDayId(String dayId) {
  final date = _utcDay(dayId);
  // The Thursday of this week decides the week-year.
  final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
  final weekYear = thursday.year;
  final dayOfYear = thursday.difference(DateTime.utc(weekYear)).inDays;
  final week = dayOfYear ~/ 7 + 1;
  return '$weekYear-W${week.toString().padLeft(2, '0')}';
}

/// The seven local calendar days (`yyyy-MM-dd`, Monday…Sunday) in the ISO
/// week that holds [dayId].
List<String> dayIdsInIsoWeekContaining(String dayId) {
  final date = _utcDay(dayId);
  final monday = date.subtract(Duration(days: date.weekday - DateTime.monday));
  return List<String>.generate(
    7,
    (i) => _formatUtcDay(monday.add(Duration(days: i))),
  );
}

DateTime _utcDay(String dayId) {
  final parts = dayId.split('-');
  if (parts.length != 3) {
    throw ArgumentError.value(dayId, 'dayId', 'not yyyy-MM-dd');
  }
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String _formatUtcDay(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
