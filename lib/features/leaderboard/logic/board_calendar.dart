import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/leaderboard_period.dart';

/// One day in the board sheet's calendar.
class BoardCalendarDay {
  const BoardCalendarDay({
    required this.dayId,
    required this.dayOfMonth,
    required this.inWindow,
  });

  /// `yyyy-MM-dd`.
  final String dayId;
  final int dayOfMonth;

  /// True for the days with a board to open: today and the 13 before it.
  final bool inWindow;
}

/// The board sheet's calendar: Monday-first weeks, like the ISO weeks of the
/// weekly board, from the week of the oldest day in [recentDayIds] to the
/// week of today. [recentDayIds] is today first (`recentLeaderboardDayIds`).
List<List<BoardCalendarDay>> boardCalendarWeeks(List<String> recentDayIds) {
  if (recentDayIds.isEmpty) return const [];
  final window = recentDayIds.toSet();
  final today = _parseDayId(recentDayIds.first);
  final oldest = _parseDayId(recentDayIds.last);
  final start = DateTime(
    oldest.year,
    oldest.month,
    oldest.day - (oldest.weekday - DateTime.monday),
  );
  final end = DateTime(
    today.year,
    today.month,
    today.day + (DateTime.sunday - today.weekday),
  );
  final weeks = <List<BoardCalendarDay>>[];
  var week = <BoardCalendarDay>[];
  for (var i = 0; ; i++) {
    // Field arithmetic, not Duration: a DST change can't skip or repeat a day.
    final date = DateTime(start.year, start.month, start.day + i);
    if (date.isAfter(end)) break;
    final dayId = leaderboardDayId(date);
    week.add(
      BoardCalendarDay(
        dayId: dayId,
        dayOfMonth: date.day,
        inWindow: window.contains(dayId),
      ),
    );
    if (week.length == 7) {
      weeks.add(week);
      week = <BoardCalendarDay>[];
    }
  }
  return weeks;
}

/// "Today", "Yesterday", or a short date for the board day [dayId]
/// (`yyyy-MM-dd`) at [index] in the recent days (today is 0).
String leaderboardDayLabel(String dayId, int index) {
  if (index == 0) return AppStrings.leaderboardToday;
  if (index == 1) return AppStrings.leaderboardYesterday;
  final date = _parseDayId(dayId);
  return AppStrings.leaderboardShortDate(date.day, date.month);
}

/// What the board pill says: the day, "This week" or "All-time". A null
/// [dayId] is today.
String leaderboardBoardLabel({
  required LeaderboardPeriod period,
  required String? dayId,
  required List<String> recentDayIds,
}) {
  switch (period) {
    case LeaderboardPeriod.weekly:
      return AppStrings.leaderboardThisWeek;
    case LeaderboardPeriod.allTime:
      return AppStrings.leaderboardAllTime;
    case LeaderboardPeriod.daily:
      if (dayId == null) return AppStrings.leaderboardToday;
      final index = recentDayIds.indexOf(dayId);
      // Outside the window (a stale day after midnight): just the date.
      return leaderboardDayLabel(dayId, index < 0 ? 2 : index);
  }
}

DateTime _parseDayId(String dayId) {
  final parts = dayId.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
