import 'app_calendar.dart';
import 'entities/game_streak.dart';

/// Pure calendar/streak math. Date ids are local `YYYYMMDD` strings.
abstract final class StreakCalculator {
  static String dateId(DateTime date) => AppCalendar.dateIdCompact(date);

  static DateTime parseDateId(String id) {
    final y = int.parse(id.substring(0, 4));
    final m = int.parse(id.substring(4, 6));
    final d = int.parse(id.substring(6, 8));
    return DateTime(y, m, d);
  }

  /// Calendar days from [fromId] to [toId] (positive if to is after from).
  static int daysBetween(String fromId, String toId) {
    return parseDateId(toId).difference(parseDateId(fromId)).inDays;
  }

  /// Lazy decay for home UI. [shouldPersist] when current was reset to 0.
  static ({GameStreak streak, bool shouldPersist}) applyLazyDecay({
    required GameStreak streak,
    required String todayId,
  }) {
    final last = streak.lastClearedDateId;
    if (last == null) {
      return (
        streak: GameStreak(
          gameId: streak.gameId,
          longest: streak.longest,
          freezeAvailable: streak.freezeAvailable,
        ),
        shouldPersist: false,
      );
    }

    final daysSince = daysBetween(last, todayId);

    if (daysSince <= 1) {
      return (streak: streak.copyWith(isOnFreeze: false), shouldPersist: false);
    }

    if (daysSince == 2 && streak.freezeAvailable) {
      return (streak: streak.copyWith(isOnFreeze: true), shouldPersist: false);
    }

    // Gap 2 without freeze, or gap >= 3 → reset current.
    final reset = streak.copyWith(current: 0, isOnFreeze: false);
    final changed = streak.current != 0;
    return (streak: reset, shouldPersist: changed);
  }

  /// Apply a daily clear for [todayId]. Idempotent if already cleared today.
  static GameStreak applyDailyClear({
    required GameStreak streak,
    required String todayId,
  }) {
    final last = streak.lastClearedDateId;
    if (last == todayId) {
      return streak.copyWith(isOnFreeze: false);
    }

    if (last == null) {
      return streak.copyWith(
        current: 1,
        longest: streak.longest < 1 ? 1 : streak.longest,
        lastClearedDateId: todayId,
        isOnFreeze: false,
      );
    }

    final gap = daysBetween(last, todayId);
    var current = streak.current;
    var freezeAvailable = streak.freezeAvailable;

    if (gap == 1) {
      current += 1;
    } else if (gap == 2 && freezeAvailable) {
      freezeAvailable = false;
      current += 1;
    } else {
      // Gap >= 2 without usable freeze, or gap > 2.
      current = 1;
    }

    final longest = current > streak.longest ? current : streak.longest;

    return GameStreak(
      gameId: streak.gameId,
      current: current,
      longest: longest,
      lastClearedDateId: todayId,
      freezeAvailable: freezeAvailable,
      isOnFreeze: false,
    );
  }
}
