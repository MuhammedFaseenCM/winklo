import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shared Android notification presentation (channel, small + large icons).
///
/// Must stay in sync with:
/// - AndroidManifest `default_notification_channel_id`
/// - admin-api `WINKLO_ANDROID_NOTIFICATION_CHANNEL_ID`
class AndroidNotificationDisplay {
  AndroidNotificationDisplay._();

  static const String channelId = 'winklo_high_importance';
  static const String channelName = 'Winklo';
  static const String channelDescription =
      'Gameplay reminders and product updates.';

  /// Status-bar / tray small icon (white silhouette drawable).
  static const String smallIcon = 'ic_stat_winklo';

  /// Full-color app icon shown in the notification shade.
  static const String largeIcon = 'ic_notification_large';

  /// Accent tint for the small icon (matches [ZipColors.ember]).
  static const Color accentColor = Color(0xFFFF6B2C);

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static AndroidNotificationDetails details() {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: smallIcon,
      largeIcon: const DrawableResourceAndroidBitmap(largeIcon),
      color: accentColor,
      playSound: true,
      enableVibration: true,
    );
  }

  static NotificationDetails notificationDetails() {
    return NotificationDetails(
      android: details(),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
