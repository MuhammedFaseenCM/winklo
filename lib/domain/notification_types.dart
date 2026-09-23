/// Notification type / topic / local schedule id constants.
abstract final class NotificationTypes {
  static const dailyReady = 'daily_ready';
  static const streakAtRisk = 'streak_at_risk';
  static const announcement = 'announcement';
  static const appUpdate = 'app_update';

  static const topicAnnouncements = 'announcements';
  static const topicAppUpdates = 'app_updates';

  static const scheduleIdDailyReady = 1001;
  static const scheduleIdStreakAtRisk = 1002;

  static const dailyReadyHour = 8;
  static const streakAtRiskHour = 20;
}
