import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/language_repository_impl.dart';
import 'android_notification_display.dart';

/// Top-level FCM background handler (must not be a class method).
///
/// When the payload is data-only (no `notification` block), Android will not
/// auto-display — we post a local notification with the full-color large icon.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');

  // System tray already posted a notification for this message.
  if (message.notification != null) return;

  final title = _stringData(message.data, 'title');
  final body = _stringData(message.data, 'body');
  if (title == null && body == null) return;

  await _useStoredLanguage();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(
        AndroidNotificationDisplay.smallIcon,
      ),
    ),
  );

  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationDisplay.announcementsChannel,
  );

  final type = _stringData(message.data, 'type') ?? 'general';
  final id =
      message.messageId?.hashCode ??
      DateTime.now().millisecondsSinceEpoch.remainder(100000);

  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: AndroidNotificationDisplay.announcementDetails(),
    payload: jsonEncode({
      'id': message.messageId ?? id.toString(),
      'title': title ?? '',
      'body': body ?? '',
      'type': type,
      'data': message.data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }),
  );
}

/// This isolate never ran the app, so AppStrings would read English, and
/// Android renames an existing channel to whatever name it's given: put the
/// strings in the player's language first.
Future<void> _useStoredLanguage() async {
  try {
    useStoredLanguage(await SharedPreferences.getInstance(), [
      for (final locale in PlatformDispatcher.instance.locales)
        locale.languageCode,
    ]);
  } catch (e) {
    debugPrint('FCM background: no stored language ($e); using English.');
  }
}

String? _stringData(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}
