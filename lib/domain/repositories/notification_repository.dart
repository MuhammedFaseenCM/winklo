import '../habit/engagement_reminder.dart';

abstract class NotificationRepository {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<bool> areNotificationsEnabled();

  /// Persist FCM token on `users/{uid}` and subscribe to product topics
  /// (announcements only while the player wants them).
  Future<void> syncTokenForUser(String uid);

  Future<void> clearTokenOnSignOut({String? uid});

  /// Cancels every local engagement notification, then schedules
  /// [reminders]. Never throws.
  Future<void> replaceEngagementSchedules(List<EngagementReminder> reminders);

  /// Subscribes to or unsubscribes from the announcements topic. Never
  /// throws.
  Future<void> setAnnouncementsSubscribed(bool subscribed);

  Stream<NotificationTap> watchTaps();
}

class NotificationTap {
  const NotificationTap({required this.type, required this.route});

  final String type;
  final String route;
}
