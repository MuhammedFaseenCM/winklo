import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/engagement_notification_schedule.dart';
import '../../domain/notification_types.dart';
import '../../domain/repositories/notification_repository.dart';
import '../clients/notification/notification_client.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required NotificationClient notificationClient,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _client = notificationClient,
       _firestore = firestore,
       _messaging = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final NotificationClient _client;
  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  FirebaseMessaging? get _fcm {
    if (!FirebaseBootstrap.isReady) return null;
    return _messaging ?? FirebaseMessaging.instance;
  }

  @override
  Future<void> initialize() async {
    await _client.initialize();
    _client.configureForegroundNotificationPresentation();
  }

  @override
  Future<bool> requestPermission() async {
    final fcm = _fcm;
    if (fcm == null) return false;
    try {
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
      return authorized;
    } catch (e) {
      debugPrint('requestPermission failed: $e');
      return false;
    }
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    final fcm = _fcm;
    if (fcm == null) return false;
    try {
      final settings = await fcm.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> syncTokenForUser(String uid) async {
    if (!FirebaseBootstrap.isReady) return;
    try {
      await requestPermission();
      final token = await _client.getDeviceToken();
      final db = _db;
      if (token != null && db != null) {
        await db.collection('users').doc(uid).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await _client.subscribeToTopic(NotificationTypes.topicAnnouncements);
      await _client.subscribeToTopic(NotificationTypes.topicAppUpdates);
    } catch (e) {
      debugPrint('syncTokenForUser failed: $e');
    }
  }

  @override
  Future<void> clearTokenOnSignOut({String? uid}) async {
    try {
      await _client.unsubscribeFromTopic(NotificationTypes.topicAnnouncements);
      await _client.unsubscribeFromTopic(NotificationTypes.topicAppUpdates);
      final db = _db;
      if (uid != null && db != null) {
        await db.collection('users').doc(uid).set({
          'fcmToken': FieldValue.delete(),
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await _client.regenerateFcmToken();
    } catch (e) {
      debugPrint('clearTokenOnSignOut failed: $e');
    }
  }

  @override
  Future<void> refreshEngagementSchedules({
    required bool zipClearedToday,
    required bool pathWordsClearedToday,
    required String dailyReadyTitle,
    required String dailyReadyBody,
    required String streakAtRiskTitle,
    required String streakAtRiskBody,
  }) async {
    try {
      final dailyWhen = EngagementNotificationSchedule.nextDailyAtHour(
        NotificationTypes.dailyReadyHour,
      );
      await _client.cancelNotification(NotificationTypes.scheduleIdDailyReady);
      await _client.scheduleNotification(
        id: NotificationTypes.scheduleIdDailyReady,
        title: dailyReadyTitle,
        body: dailyReadyBody,
        when: dailyWhen,
        type: NotificationTypes.dailyReady,
        data: {'route': '/'},
        repeatsDaily: true,
      );

      await _client.cancelNotification(
        NotificationTypes.scheduleIdStreakAtRisk,
      );
      final scheduleStreak =
          EngagementNotificationSchedule.shouldScheduleStreakAtRisk(
            zipClearedToday: zipClearedToday,
            pathWordsClearedToday: pathWordsClearedToday,
          );
      if (scheduleStreak) {
        final streakWhen = EngagementNotificationSchedule.nextDailyAtHour(
          NotificationTypes.streakAtRiskHour,
        );
        await _client.scheduleNotification(
          id: NotificationTypes.scheduleIdStreakAtRisk,
          title: streakAtRiskTitle,
          body: streakAtRiskBody,
          when: streakWhen,
          type: NotificationTypes.streakAtRisk,
          data: {'route': '/'},
          repeatsDaily: true,
        );
      }
    } catch (e) {
      debugPrint('refreshEngagementSchedules failed: $e');
    }
  }

  @override
  Stream<NotificationTap> watchTaps() {
    return _client.onNotificationTapped.map(
      (message) => NotificationTap(type: message.type, route: message.route),
    );
  }
}
