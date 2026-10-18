import '../entities/reminder_settings.dart';
import '../habit/engagement_planner.dart';
import '../habit/game_habit_status.dart';
import '../habit/weekly_recap.dart';
import '../repositories/notification_repository.dart';

/// Replans every local engagement notification (see [EngagementPlanner]).
class ScheduleEngagementNotifications {
  ScheduleEngagementNotifications(this._repo);
  final NotificationRepository _repo;

  /// [recap] is the week of [EngagementPlanner.nextWeeklyRecapAt].
  Future<void> call({
    required ReminderSettings settings,
    required List<GameHabitStatus> games,
    required DateTime now,
    WeeklyRecap? recap,
  }) => _repo.replaceEngagementSchedules(
    EngagementPlanner.plan(
      settings: settings,
      games: games,
      now: now,
      recap: recap,
    ),
  );
}
