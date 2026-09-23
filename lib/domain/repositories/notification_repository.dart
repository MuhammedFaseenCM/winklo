abstract class NotificationRepository {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<bool> areNotificationsEnabled();

  /// Persist FCM token on `users/{uid}` and subscribe to product topics.
  Future<void> syncTokenForUser(String uid);

  Future<void> clearTokenOnSignOut({String? uid});

  Future<void> refreshEngagementSchedules({
    required bool zipClearedToday,
    required bool pathWordsClearedToday,
    required String dailyReadyTitle,
    required String dailyReadyBody,
    required String streakAtRiskTitle,
    required String streakAtRiskBody,
  });

  Stream<NotificationTap> watchTaps();
}

class NotificationTap {
  const NotificationTap({required this.type, required this.route});

  final String type;
  final String route;
}
