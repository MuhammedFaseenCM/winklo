import '../app_calendar.dart';
import '../logic/daily_live_window.dart';
import '../play_period.dart';
import '../repositories/daily_puzzle_prefetch_repository.dart';

/// After Home loads, reads tomorrow's three dailies once they are live, so a
/// player who is offline tomorrow still has them.
///
/// A day is done for the app session once all three docs were read. A read
/// that didn't get them all (the rules refuse a daily that isn't live yet,
/// as when the phone's clock runs a little ahead, or the phone is offline)
/// is tried again on a later call, no sooner than [retryAfter]. Every error
/// is ignored.
class PrefetchTomorrowPuzzles {
  PrefetchTomorrowPuzzles(
    this._repository, {
    this.period = PlayPeriod.daily,
    this.retryAfter = const Duration(minutes: 10),
  });

  final DailyPuzzlePrefetchRepository _repository;

  /// Debug builds can rotate puzzles every minute; those aren't prefetched.
  final Duration period;

  /// The shortest wait after a failed read before the next try.
  final Duration retryAfter;

  final Set<String> _done = {};
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _failedAt = {};

  Future<void> call(DateTime now) async {
    if (PlayPeriod.isSubDaily(period)) return;
    final today = AppCalendar.calendarDay(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    if (!DailyLiveWindow.isLive(tomorrow, now)) return;
    final dateId = PlayPeriod.id(tomorrow, PlayPeriod.daily);
    if (_done.contains(dateId) || _inFlight.contains(dateId)) return;
    final failedAt = _failedAt[dateId];
    if (failedAt != null && now.difference(failedAt) < retryAfter) return;

    _inFlight.add(dateId);
    var readAll = false;
    try {
      readAll = await _repository.prefetch(dateId);
    } catch (_) {
      // Only a cache warm-up; tomorrow's game reads the puzzle itself.
    } finally {
      _inFlight.remove(dateId);
    }
    if (readAll) {
      _done.add(dateId);
      _failedAt.remove(dateId);
    } else {
      _failedAt[dateId] = now;
    }
  }
}
