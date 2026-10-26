import '../engagement_notification_schedule.dart';
import '../entities/reminder_settings.dart';
import '../notification_types.dart';
import '../streak_calculator.dart';
import 'engagement_reminder.dart';
import 'game_habit_status.dart';
import 'weekly_recap.dart';

/// Decides which engagement notifications to schedule, and when.
///
/// Every refresh (app open, clear, midnight, a settings change) replans
/// from scratch, so a reminder only has to be right until the app is next
/// used. Every reminder is a one-off, so each can say something new: the
/// mornings of [morningOffsets], and streak reminders for tonight and for
/// tomorrow evening (in case the app isn't opened in between).
abstract final class EngagementPlanner {
  /// Days after the first morning that get a morning reminder: a week, then
  /// day 10 and day 14, then nothing until the app is opened again. A player
  /// who opens the app daily only ever gets the first.
  static const morningOffsets = [0, 1, 2, 3, 4, 5, 6, 9, 13];

  /// A streak this long or longer is worth naming in the morning.
  static const morningStreakMinDays = 3;

  /// [games] are in display order (Zip, Path Words, Sudoku), which breaks
  /// ties. [recap] is the week of [nextWeeklyRecapAt]; an empty or missing
  /// one is not sent.
  static List<EngagementReminder> plan({
    required ReminderSettings settings,
    required List<GameHabitStatus> games,
    required DateTime now,
    WeeklyRecap? recap,
  }) {
    return [
      if (settings.dailyReadyEnabled)
        ...morningReminders(
          games: games,
          now: now,
          minutes: settings.dailyReadyMinutes,
        ),
      if (settings.streakAtRiskEnabled)
        ...streakReminders(
          games: games,
          now: now,
          minutes: settings.streakReminderMinutes,
        ),
      if (settings.weeklyRecapEnabled && recap != null && !recap.isEmpty)
        WeeklyRecapReminder(
          when: nextWeeklyRecapAt(settings, now),
          recap: recap,
        ),
    ];
  }

  /// Sunday at [ReminderSettings.weeklyRecapMinutes]: today when it is
  /// Sunday and that time is still ahead.
  static DateTime nextWeeklyRecapAt(ReminderSettings settings, DateTime now) =>
      EngagementNotificationSchedule.nextWeekdayAt(
        DateTime.sunday,
        settings.weeklyRecapMinutes,
        now: now,
      );

  /// The first morning is the next time the clock shows [minutes], or
  /// tomorrow's when that is today and every game is already cleared. The
  /// first one names the longest streak alive that morning: today, an
  /// uncleared game's current streak; tomorrow, what
  /// [StreakCalculator.atStakeTomorrow] says survives today.
  static List<DailyReadyReminder> morningReminders({
    required List<GameHabitStatus> games,
    required DateTime now,
    required int minutes,
  }) {
    final todayId = StreakCalculator.dateId(now);
    final allCleared =
        games.isNotEmpty && games.every((game) => game.clearedOn(todayId));
    var first = EngagementNotificationSchedule.nextDailyAt(minutes, now: now);
    var firstIsToday = StreakCalculator.dateId(first) == todayId;
    if (firstIsToday && allCleared) {
      first = EngagementNotificationSchedule.atMinutes(
        now,
        minutes,
        dayOffset: 1,
      );
      firstIsToday = false;
    }

    final stakes = [
      for (final game in games)
        (
          gameId: game.gameId,
          days: firstIsToday
              ? (game.clearedOn(todayId) ? 0 : game.streak.current)
              : StreakCalculator.atStakeTomorrow(
                  streak: game.streak,
                  todayId: todayId,
                ),
        ),
    ];
    final streak = _longest(stakes);
    final named = streak != null && streak.days >= morningStreakMinDays;

    return [
      for (var slot = 0; slot < morningOffsets.length; slot++)
        DailyReadyReminder(
          when: EngagementNotificationSchedule.atMinutes(
            first,
            minutes,
            dayOffset: morningOffsets[slot],
          ),
          slot: slot,
          phase: _phaseOf(slot),
          streakGameId: slot == 0 && named ? streak.gameId : null,
          streakDays: slot == 0 && named ? streak.days : 0,
        ),
    ];
  }

  static MorningPhase _phaseOf(int slot) => switch (morningOffsets[slot]) {
    0 => MorningPhase.active,
    <= 6 => MorningPhase.lapsed,
    <= 9 => MorningPhase.missYou,
    _ => MorningPhase.lastCall,
  };

  /// Tonight: the uncleared games with a current streak (none: no reminder).
  /// Tomorrow evening: what would still be at stake if today passed without
  /// a clear ([StreakCalculator.atStakeTomorrow]).
  static List<StreakAtRiskReminder> streakReminders({
    required List<GameHabitStatus> games,
    required DateTime now,
    required int minutes,
  }) {
    final todayId = StreakCalculator.dateId(now);
    final tonightAt = EngagementNotificationSchedule.atMinutes(now, minutes);
    final tomorrowAt = EngagementNotificationSchedule.atMinutes(
      now,
      minutes,
      dayOffset: 1,
    );

    final tonight = [
      for (final game in games)
        if (!game.clearedOn(todayId) && game.streak.current >= 1)
          (gameId: game.gameId, days: game.streak.current),
    ];
    final tomorrow = [
      for (final game in games)
        (
          gameId: game.gameId,
          days: StreakCalculator.atStakeTomorrow(
            streak: game.streak,
            todayId: todayId,
          ),
        ),
    ].where((stake) => stake.days >= 1).toList();

    return [
      if (tonightAt.isAfter(now) && tonight.isNotEmpty)
        _reminder(NotificationTypes.scheduleIdStreakAtRisk, tonightAt, tonight),
      if (tomorrow.isNotEmpty)
        _reminder(
          NotificationTypes.scheduleIdStreakAtRiskTomorrow,
          tomorrowAt,
          tomorrow,
        ),
    ];
  }

  /// The longest of [stakes] with at least a day; the first listed wins a
  /// tie.
  static ({String gameId, int days})? _longest(
    List<({String gameId, int days})> stakes,
  ) {
    ({String gameId, int days})? top;
    for (final stake in stakes) {
      if (stake.days >= 1 && (top == null || stake.days > top.days)) {
        top = stake;
      }
    }
    return top;
  }

  /// Names the longest streak; the first listed wins a tie.
  static StreakAtRiskReminder _reminder(
    int id,
    DateTime when,
    List<({String gameId, int days})> stakes,
  ) {
    final top = _longest(stakes)!;
    return StreakAtRiskReminder(
      when: when,
      id: id,
      gameId: top.gameId,
      days: top.days,
      others: stakes.length - 1,
    );
  }
}
