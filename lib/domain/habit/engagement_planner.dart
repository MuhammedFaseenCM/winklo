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
/// used. Streak reminders are one-offs whose text names the streak, for
/// tonight and for tomorrow evening (in case the app isn't opened in
/// between).
abstract final class EngagementPlanner {
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
        DailyReadyReminder(
          when: EngagementNotificationSchedule.nextDailyAt(
            settings.dailyReadyMinutes,
            now: now,
          ),
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

  /// Names the longest streak; the first listed wins a tie.
  static StreakAtRiskReminder _reminder(
    int id,
    DateTime when,
    List<({String gameId, int days})> stakes,
  ) {
    var top = stakes.first;
    for (final stake in stakes.skip(1)) {
      if (stake.days > top.days) top = stake;
    }
    return StreakAtRiskReminder(
      when: when,
      id: id,
      gameId: top.gameId,
      days: top.days,
      others: stakes.length - 1,
    );
  }
}
