import 'notification_message.dart';

/// Platform notification surface (FCM + local), Urbania-aligned for Winklo.
abstract class NotificationClient {
  Future<void> initialize();

  Future<String?> getDeviceToken();

  Future<String?> regenerateFcmToken();

  Future<void> subscribeToTopic(String topic);

  Future<void> unsubscribeFromTopic(String topic);

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String type = 'local',
  });

  /// Schedule a one-shot or repeating local notification at [when] (local).
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    Map<String, dynamic>? data,
    required String type,
    bool repeatsDaily = false,
  });

  Future<void> cancelNotification(int id);

  void configureForegroundNotificationPresentation({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  });

  Future<void> clearAllNotifications();

  Stream<NotificationMessage> get onForegroundMessage;

  Stream<NotificationMessage> get onNotificationTapped;

  Stream<String> get onTokenRefresh;

  void dispose();
}
