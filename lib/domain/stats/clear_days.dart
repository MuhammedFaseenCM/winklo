import '../entities/game_day_record.dart';

// Shared helpers for stats and achievements over cleared game days.

final _playIdPattern = RegExp(r'^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{4})?$');

/// Local calendar date of a play period (`YYYYMMDD`, or a debug
/// `YYYYMMDDHHmm` minute period, which collapses to its day). Null when
/// [playId] is not a valid period id.
DateTime? dateOfPlayId(String playId) {
  final match = _playIdPattern.firstMatch(playId);
  if (match == null) return null;
  final y = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  final d = int.parse(match.group(3)!);
  final date = DateTime(y, m, d);
  if (date.year != y || date.month != m || date.day != d) return null;
  return date;
}

/// A clear made without hints. Uses the stored flag; without one, a hint
/// quota of 0 that day means certainly no hints.
bool isHintFree(GameDayRecord day) {
  if (!day.cleared) return false;
  final used = day.usedHints;
  if (used != null) return !used;
  return day.hintsUsed == 0;
}

/// A clear with no hints and no mistakes. Unknown mistakes (legacy Sudoku
/// clears) don't count.
bool isFlawless(GameDayRecord day) =>
    isHintFree(day) && day.hadMistakes == false;

/// Longest run of consecutive calendar days in [days] (duplicates and order
/// don't matter).
int longestDailyRun(Iterable<DateTime> days) {
  final sorted = {for (final d in days) _dateOnly(d)}.toList()..sort();
  var longest = 0;
  var run = 0;
  DateTime? previous;
  for (final day in sorted) {
    run = previous != null && _isNextDay(previous, day) ? run + 1 : 1;
    if (run > longest) longest = run;
    previous = day;
  }
  return longest;
}

/// Fastest clear time per local date (debug minute periods share a date).
/// Uncleared days and malformed ids are skipped.
Map<DateTime, int> bestTimeByDate(Iterable<GameDayRecord> days) {
  final byDate = <DateTime, int>{};
  for (final day in days) {
    final time = day.timeSeconds;
    final date = dateOfPlayId(day.playId);
    if (time == null || date == null) continue;
    final best = byDate[date];
    if (best == null || time < best) byDate[date] = time;
  }
  return byDate;
}

/// Calendar day [offset] days after [date], built from Y/M/D so a DST change
/// never skips or repeats a day.
DateTime addDays(DateTime date, int offset) =>
    DateTime(date.year, date.month, date.day + offset);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isNextDay(DateTime previous, DateTime day) {
  final next = addDays(previous, 1);
  return next.year == day.year &&
      next.month == day.month &&
      next.day == day.day;
}
