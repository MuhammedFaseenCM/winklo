import '../app_calendar.dart';
import '../logic/daily_live_window.dart';
import '../play_period.dart';
import '../repositories/daily_puzzle_prefetch_repository.dart';

/// After Home loads, reads tomorrow's three dailies once they are live, so a
/// player who is offline tomorrow still has them.
///
/// Each day is tried at most once per app session, whatever the outcome:
/// reads before a day is live are refused by the rules, and every error is
/// ignored.
class PrefetchTomorrowPuzzles {
  PrefetchTomorrowPuzzles(this._repository, {this.period = PlayPeriod.daily});

  final DailyPuzzlePrefetchRepository _repository;

  /// Debug builds can rotate puzzles every minute; those aren't prefetched.
  final Duration period;
  final Set<String> _tried = {};

  Future<void> call(DateTime now) async {
    if (PlayPeriod.isSubDaily(period)) return;
    final today = AppCalendar.calendarDay(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    if (!DailyLiveWindow.isLive(tomorrow, now)) return;
    final dateId = PlayPeriod.id(tomorrow, PlayPeriod.daily);
    if (!_tried.add(dateId)) return;
    try {
      await _repository.prefetch(dateId);
    } catch (_) {
      // Only a cache warm-up; tomorrow's game reads the puzzle itself.
    }
  }
}
