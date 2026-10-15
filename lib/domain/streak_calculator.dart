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
          freezeCount: streak.freezeCount,
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
  }) => dailyClear(streak: streak, todayId: todayId).streak;

  /// [applyDailyClear], also saying whether a freeze carried the streak over
  /// a missed day ([freezeSpent]) and whether this clear earned one
  /// ([freezeEarned]). Both can be true: a spend that lands on day 14 earns
  /// the freeze straight back.
  ///
  /// A 2-day gap spends a freeze; a longer gap resets the streak and keeps
  /// the freezes. A clear that brings the streak to a multiple of
  /// [GameStreak.freezeEarnEvery] earns one, up to [GameStreak.maxFreezes].
  static ({GameStreak streak, bool freezeSpent, bool freezeEarned}) dailyClear({
    required GameStreak streak,
    required String todayId,
  }) {
    final last = streak.lastClearedDateId;
    if (last == todayId) {
      return (
        streak: streak.copyWith(isOnFreeze: false),
        freezeSpent: false,
        freezeEarned: false,
      );
    }

    var current = streak.current;
    var freezes = _clampFreezes(streak.freezeCount);
    var spent = false;

    if (last == null) {
      current = 1;
    } else {
      final gap = daysBetween(last, todayId);
      if (gap == 1) {
        current += 1;
      } else if (gap == 2 && freezes > 0) {
        freezes -= 1;
        spent = true;
        current += 1;
      } else {
        // Gap >= 2 without usable freeze, or gap > 2.
        current = 1;
      }
    }

    var earned = false;
    if (current % GameStreak.freezeEarnEvery == 0 &&
        freezes < GameStreak.maxFreezes) {
      freezes += 1;
      earned = true;
    }

    final longest = current > streak.longest ? current : streak.longest;

    return (
      streak: GameStreak(
        gameId: streak.gameId,
        current: current,
        longest: longest,
        lastClearedDateId: todayId,
        freezeCount: freezes,
        isOnFreeze: false,
      ),
      freezeSpent: spent,
      freezeEarned: earned,
    );
  }

  /// The freeze count of a stored streak, from the stored [count] (null when
  /// missing: older builds never write it) and the `freezeAvailable` flag
  /// [available] that every build writes (null when missing: true).
  ///
  /// New builds always write `available == count > 0`. A pair that disagrees
  /// means an older build wrote the flag afterwards: `true` with no freezes
  /// reads as the one freeze that build knows of, and `false` with freezes
  /// as one spent by it.
  static int storedFreezeCount({int? count, bool? available}) {
    final flag = available ?? true;
    if (count == null) return flag ? 1 : 0;
    final freezes = _clampFreezes(count);
    if (flag && freezes == 0) return 1;
    if (!flag && freezes > 0) return freezes - 1;
    return freezes;
  }

  /// The streak that ends at tomorrow's midnight unless that day is cleared,
  /// if today passes without a clear: 0 when nothing would be left by then.
  ///
  /// [streak] is decayed to [todayId] (as `GetStreak` returns it). A streak
  /// cleared today carries on; one last cleared yesterday only lasts with a
  /// freeze; one already on a freeze (or reset) is gone.
  static int atStakeTomorrow({
    required GameStreak streak,
    required String todayId,
  }) {
    final last = streak.lastClearedDateId;
    if (last == null || streak.current < 1) return 0;
    final daysSince = daysBetween(last, todayId);
    if (daysSince <= 0) return streak.current;
    if (daysSince == 1 && streak.freezeCount > 0) return streak.current;
    return 0;
  }

  static int _clampFreezes(int count) =>
      count.clamp(0, GameStreak.maxFreezes).toInt();
}
