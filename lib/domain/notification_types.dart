/// Notification type / topic / local schedule id constants.
abstract final class NotificationTypes {
  static const dailyReady = 'daily_ready';
  static const streakAtRisk = 'streak_at_risk';
  static const weeklyRecap = 'weekly_recap';
  static const announcement = 'announcement';
  static const appUpdate = 'app_update';

  static const topicAnnouncements = 'announcements';
  static const topicAppUpdates = 'app_updates';

  static const scheduleIdDailyReady = 1001;

  /// Tonight's streak reminder (or the next evening's, when tonight has
  /// nothing at stake).
  static const scheduleIdStreakAtRisk = 1002;
  static const scheduleIdWeeklyRecap = 1003;

  /// The evening after, in case the app isn't opened in between.
  static const scheduleIdStreakAtRiskTomorrow = 1004;

  /// Every local engagement schedule; each refresh cancels them all first.
  static const engagementScheduleIds = [
    scheduleIdDailyReady,
    scheduleIdStreakAtRisk,
    scheduleIdWeeklyRecap,
    scheduleIdStreakAtRiskTomorrow,
  ];

  /// Defaults; players choose their own times in Settings.
  static const dailyReadyHour = 8;
  static const streakAtRiskHour = 20;
}
