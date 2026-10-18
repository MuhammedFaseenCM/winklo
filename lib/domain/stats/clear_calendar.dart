/// One month of the cleared-days calendar.
class ClearCalendarMonth {
  const ClearCalendarMonth({
    required this.year,
    required this.month,
    this.clearedDays = const {},
  });

  final int year;

  /// 1–12.
  final int month;

  /// Days of the month (1–31) with a clear.
  final Set<int> clearedDays;

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// Empty cells before day 1 in a week starting on [firstDayOfWeekIndex]
  /// (0 = Sunday, as `MaterialLocalizations.firstDayOfWeekIndex`).
  int leadingBlanks({required int firstDayOfWeekIndex}) {
    final weekday = DateTime(year, month).weekday % 7; // Sunday = 0
    return (weekday - firstDayOfWeekIndex) % 7;
  }

  @override
  bool operator ==(Object other) =>
      other is ClearCalendarMonth &&
      other.year == year &&
      other.month == month &&
      other.clearedDays.length == clearedDays.length &&
      other.clearedDays.containsAll(clearedDays);

  @override
  int get hashCode =>
      Object.hash(year, month, Object.hashAllUnordered(clearedDays));

  @override
  String toString() => 'ClearCalendarMonth($year-$month: $clearedDays)';
}

/// Months from the first cleared month to the current month (or a later
/// cleared one), oldest first, each with its cleared days. Months without a
/// clear in between are kept, so the calendar pages without jumps. Empty for
/// no clears.
List<ClearCalendarMonth> clearCalendar(
  Iterable<DateTime> clearedDates, {
  required DateTime today,
}) {
  final byMonth = <int, Set<int>>{};
  for (final date in clearedDates) {
    (byMonth[_monthIndex(date.year, date.month)] ??= {}).add(date.day);
  }
  if (byMonth.isEmpty) return const [];

  final first = byMonth.keys.reduce((a, b) => a < b ? a : b);
  var last = _monthIndex(today.year, today.month);
  for (final key in byMonth.keys) {
    if (key > last) last = key;
  }
  return [
    for (var index = first; index <= last; index++)
      ClearCalendarMonth(
        year: index ~/ 12,
        month: index % 12 + 1,
        clearedDays: byMonth[index] ?? const {},
      ),
  ];
}

int _monthIndex(int year, int month) => year * 12 + (month - 1);
