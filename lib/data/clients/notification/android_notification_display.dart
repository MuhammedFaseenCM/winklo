import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/strings/app_strings.dart';

/// Shared Android notification presentation (channels, small + large icons).
///
/// Two channels, so players can silence one kind in system settings:
/// [remindersChannelId] for the local reminders and the weekly recap, and
/// [announcementsChannelId] for FCM announcements and app updates.
///
/// [announcementsChannelId] must stay in sync with:
/// - AndroidManifest `default_notification_channel_id`
/// - admin-api `WINKLO_ANDROID_NOTIFICATION_CHANNEL_ID`
class AndroidNotificationDisplay {
  AndroidNotificationDisplay._();

  static const String remindersChannelId = 'winklo_reminders';
  static const String announcementsChannelId = 'winklo_announcements';

  /// The single channel of builds up to 1.0.0+18. Never deleted: reminders
  /// those builds scheduled still post to it until the app replans them.
  static const String legacyChannelId = 'winklo_high_importance';

  /// Status-bar / tray small icon (white silhouette drawable).
  static const String smallIcon = 'ic_stat_winklo';

  /// Full-color app icon shown in the notification shade.
  static const String largeIcon = 'ic_notification_large';

  /// Accent tint for the small icon (matches [ZipColors.ember]).
  static const Color accentColor = Color(0xFFFF6B2C);

  static const AndroidNotificationChannel remindersChannel =
      AndroidNotificationChannel(
        remindersChannelId,
        AppStrings.channelRemindersName,
        description: AppStrings.channelRemindersDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  static const AndroidNotificationChannel announcementsChannel =
      AndroidNotificationChannel(
        announcementsChannelId,
        AppStrings.channelAnnouncementsName,
        description: AppStrings.channelAnnouncementsDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  /// Created at start-up.
  static const channels = [remindersChannel, announcementsChannel];

  static NotificationDetails reminderDetails() => _details(remindersChannel);

  static NotificationDetails announcementDetails() =>
      _details(announcementsChannel);

  static NotificationDetails _details(AndroidNotificationChannel channel) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: smallIcon,
        largeIcon: const DrawableResourceAndroidBitmap(largeIcon),
        color: accentColor,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
