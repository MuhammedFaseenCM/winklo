import 'play_mode.dart';

/// One month of the archive calendar for one game.
class ArchiveMonth {
  const ArchiveMonth({
    required this.year,
    required this.month,
    required this.firstDay,
    required this.lastDay,
    this.clearedDays = const {},
  });

  final int year;

  /// 1–12.
  final int month;

  /// The first and last days of the month that are in the archive.
  final int firstDay;
  final int lastDay;

  /// Days cleared in the daily or in the archive.
  final Set<int> clearedDays;

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  bool isPlayable(int day) => day >= firstDay && day <= lastDay;

  /// Empty cells before day 1 in a week starting on [firstDayOfWeekIndex]
  /// (0 = Sunday, as `MaterialLocalizations.firstDayOfWeekIndex`).
  int leadingBlanks({required int firstDayOfWeekIndex}) {
    final weekday = DateTime(year, month).weekday % 7; // Sunday = 0
    return (weekday - firstDayOfWeekIndex) % 7;
  }

  @override
  bool operator ==(Object other) =>
      other is ArchiveMonth &&
      other.year == year &&
      other.month == month &&
      other.firstDay == firstDay &&
      other.lastDay == lastDay &&
      other.clearedDays.length == clearedDays.length &&
      other.clearedDays.containsAll(clearedDays);

  @override
  int get hashCode => Object.hash(
    year,
    month,
    firstDay,
    lastDay,
    Object.hashAllUnordered(clearedDays),
  );

  @override
  String toString() =>
      'ArchiveMonth($year-$month, $firstDay–$lastDay, $clearedDays)';
}

/// The archive's months, oldest first: from [PlayMode.archiveFirstDay] to
/// yesterday. [isCleared] says whether a day was cleared (daily or archive).
/// Empty before the archive's first day has passed.
List<ArchiveMonth> archiveMonths({
  required DateTime now,
  required bool Function(DateTime day) isCleared,
}) {
  final first = PlayMode.archiveFirstDay;
  final last = PlayMode.archiveLastDay(now);
  if (last.isBefore(first)) return const [];
  final months = <ArchiveMonth>[];
  var year = first.year;
  var month = first.month;
  while (year < last.year || (year == last.year && month <= last.month)) {
    final from = year == first.year && month == first.month ? first.day : 1;
    final to = year == last.year && month == last.month
        ? last.day
        : DateTime(year, month + 1, 0).day;
    months.add(
      ArchiveMonth(
        year: year,
        month: month,
        firstDay: from,
        lastDay: to,
        clearedDays: {
          for (var d = from; d <= to; d++)
            if (isCleared(DateTime(year, month, d))) d,
        },
      ),
    );
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }
  return months;
}
