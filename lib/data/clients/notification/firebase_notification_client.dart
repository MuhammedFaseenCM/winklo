import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/firebase/firebase_bootstrap.dart';
import 'firebase_messaging_background.dart';
import 'notification_client.dart';
import 'notification_message.dart';

class FirebaseNotificationClient implements NotificationClient {
  FirebaseNotificationClient({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final _foregroundMessageController =
      StreamController<NotificationMessage>.broadcast();
  final _notificationTappedController =
      StreamController<NotificationMessage>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'winklo_high_importance',
    'Winklo',
    description: 'Gameplay reminders and product updates.',
    importance: Importance.high,
  );

  /// Status-bar icon (white silhouette drawable name, no `@drawable/`).
  static const String _androidNotificationIcon = 'ic_stat_winklo';

  @override
  Stream<NotificationMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;

  @override
  Stream<NotificationMessage> get onNotificationTapped =>
      _notificationTappedController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (!FirebaseBootstrap.isReady) {
      debugPrint('FirebaseNotificationClient: Firebase not ready — skip');
      return;
    }

    await _configureLocalTimezone();
    await _initializeLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (!_notificationTappedController.isClosed) {
          _notificationTappedController.add(
            _fromRemoteMessage(initialMessage),
          );
        }
      });
    }

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _notificationTappedController.add(_fromRemoteMessage(message));
    });

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotificationFromRemote(message);
      _foregroundMessageController.add(_fromRemoteMessage(message));
    });

    _messaging.onTokenRefresh.listen((token) {
      _tokenRefreshController.add(token);
    });

    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone init failed, using UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  NotificationMessage _fromRemoteMessage(RemoteMessage message) {
    return NotificationMessage(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map<String, dynamic>.from(message.data),
      type: message.data['type'] ?? 'general',
      receivedAt: DateTime.now(),
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings(_androidNotificationIcon);
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          _notificationTappedController.add(
            NotificationMessage.fromPayloadMap(map),
          );
        } catch (e) {
          debugPrint('Notification tap payload error: $e');
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  String _encodePayload({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
    String? id,
  }) {
    return jsonEncode({
      'id': id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'type': type,
      'data': {'type': type, ...?data},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: _androidNotificationIcon,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  void _showLocalNotificationFromRemote(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    if (!Platform.isAndroid) return;

    final type = message.data['type'] ?? 'general';
    unawaited(
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: _details(),
        payload: _encodePayload(
          title: notification.title ?? '',
          body: notification.body ?? '',
          type: type,
          data: Map<String, dynamic>.from(message.data),
          id: message.messageId,
        ),
      ),
    );
  }

  @override
  Future<String?> getDeviceToken() async {
    if (!FirebaseBootstrap.isReady) return null;
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('getDeviceToken failed: $e');
      return null;
    }
  }

  @override
  Future<String?> regenerateFcmToken() async {
    if (!FirebaseBootstrap.isReady) return null;
    try {
      await _messaging.deleteToken();
      final token = await _messaging.getToken();
      if (token != null) _tokenRefreshController.add(token);
      return token;
    } catch (e) {
      debugPrint('regenerateFcmToken failed: $e');
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    if (!FirebaseBootstrap.isReady) return;
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('subscribeToTopic($topic) failed: $e');
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!FirebaseBootstrap.isReady) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('unsubscribeFromTopic($topic) failed: $e');
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  @override
  void configureForegroundNotificationPresentation({
    bool alert = true,
    bool badge = true,
    bool sound = true,
  }) {
    if (!FirebaseBootstrap.isReady) return;
    unawaited(
      _messaging.setForegroundNotificationPresentationOptions(
        alert: alert,
        badge: badge,
        sound: sound,
      ),
    );
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String type = 'local',
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(),
      payload: _encodePayload(title: title, body: body, type: type, data: data),
    );
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    Map<String, dynamic>? data,
    required String type,
    bool repeatsDaily = false,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: repeatsDaily ? DateTimeComponents.time : null,
      payload: _encodePayload(title: title, body: body, type: type, data: data),
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id: id);
  }

  @override
  void dispose() {
    _foregroundMessageController.close();
    _notificationTappedController.close();
    _tokenRefreshController.close();
  }
}
