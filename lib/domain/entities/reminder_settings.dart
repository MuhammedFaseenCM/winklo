import '../notification_types.dart';

/// Which engagement notifications the player wants, and when. Times are
/// minutes after local midnight.
class ReminderSettings {
  const ReminderSettings({
    this.dailyReadyEnabled = true,
    this.streakAtRiskEnabled = true,
    this.weeklyRecapEnabled = true,
    this.announcementsEnabled = true,
    this.dailyReadyMinutes = defaultDailyReadyMinutes,
    this.streakReminderMinutes = defaultStreakReminderMinutes,
  });

  static const minutesPerDay = 24 * 60;
  static const defaultDailyReadyMinutes = NotificationTypes.dailyReadyHour * 60;
  static const defaultStreakReminderMinutes =
      NotificationTypes.streakAtRiskHour * 60;

  /// The weekly recap comes this long before the streak reminder.
  static const weeklyRecapLead = 60;

  final bool dailyReadyEnabled;
  final bool streakAtRiskEnabled;
  final bool weeklyRecapEnabled;

  /// The `announcements` FCM topic (news). App updates stay on.
  final bool announcementsEnabled;
  final int dailyReadyMinutes;
  final int streakReminderMinutes;

  /// Sunday's recap time: an hour before the streak reminder, never before
  /// midnight.
  int get weeklyRecapMinutes {
    final minutes = streakReminderMinutes - weeklyRecapLead;
    return minutes < 0 ? 0 : minutes;
  }

  static int clampMinutes(int minutes) =>
      minutes.clamp(0, minutesPerDay - 1).toInt();

  ReminderSettings copyWith({
    bool? dailyReadyEnabled,
    bool? streakAtRiskEnabled,
    bool? weeklyRecapEnabled,
    bool? announcementsEnabled,
    int? dailyReadyMinutes,
    int? streakReminderMinutes,
  }) {
    return ReminderSettings(
      dailyReadyEnabled: dailyReadyEnabled ?? this.dailyReadyEnabled,
      streakAtRiskEnabled: streakAtRiskEnabled ?? this.streakAtRiskEnabled,
      weeklyRecapEnabled: weeklyRecapEnabled ?? this.weeklyRecapEnabled,
      announcementsEnabled: announcementsEnabled ?? this.announcementsEnabled,
      dailyReadyMinutes: dailyReadyMinutes ?? this.dailyReadyMinutes,
      streakReminderMinutes:
          streakReminderMinutes ?? this.streakReminderMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.dailyReadyEnabled == dailyReadyEnabled &&
      other.streakAtRiskEnabled == streakAtRiskEnabled &&
      other.weeklyRecapEnabled == weeklyRecapEnabled &&
      other.announcementsEnabled == announcementsEnabled &&
      other.dailyReadyMinutes == dailyReadyMinutes &&
      other.streakReminderMinutes == streakReminderMinutes;

  @override
  int get hashCode => Object.hash(
    dailyReadyEnabled,
    streakAtRiskEnabled,
    weeklyRecapEnabled,
    announcementsEnabled,
    dailyReadyMinutes,
    streakReminderMinutes,
  );
}
