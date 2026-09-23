import '../repositories/notification_repository.dart';

/// Resolves a notification tap to a go_router location (default `/`).
class HandleNotificationTap {
  String call(NotificationTap tap) {
    final route = tap.route.trim();
    if (route.isEmpty) return '/';
    return route.startsWith('/') ? route : '/';
  }
}
