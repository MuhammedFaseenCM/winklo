import 'dart:async';

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
    this._firestore,
    this._messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _client = notificationClient,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final NotificationClient _client;
  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  String? _lastSyncedUid;
  String? _lastSyncedToken;

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
        // Avoid rewrite storms: fcmUpdatedAt is a server timestamp, so every
        // write would otherwise retrigger users/{uid} listeners forever.
        if (_lastSyncedUid != uid || _lastSyncedToken != token) {
          await db.collection('users').doc(uid).set({
            'fcmToken': token,
            'fcmUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _lastSyncedUid = uid;
          _lastSyncedToken = token;
        }
      }
      await _client.subscribeToTopic(NotificationTypes.topicAnnouncements);
      await _client.subscribeToTopic(NotificationTypes.topicAppUpdates);
    } catch (e) {
      debugPrint('syncTokenForUser failed: $e');
    }
  }

  @override
  Future<void> clearTokenOnSignOut({String? uid}) async {
    // Firestore clear must finish while still signed in (rules: isOwner).
    // Topic unsubscribe / token delete often hang on emulators with flaky GMS —
    // never block sign-out on those.
    try {
      final db = _db;
      if (uid != null && db != null) {
        await db.collection('users').doc(uid).set({
          'fcmToken': FieldValue.delete(),
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _lastSyncedUid = null;
      _lastSyncedToken = null;
    } catch (e) {
      debugPrint('clearTokenOnSignOut firestore failed: $e');
    }
    unawaited(_detachLocalFcm());
  }

  Future<void> _detachLocalFcm() async {
    try {
      await _client
          .unsubscribeFromTopic(NotificationTypes.topicAnnouncements)
          .timeout(const Duration(seconds: 3));
      await _client
          .unsubscribeFromTopic(NotificationTypes.topicAppUpdates)
          .timeout(const Duration(seconds: 3));
      await _client.regenerateFcmToken().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('detachLocalFcm failed: $e');
    }
  }

  @override
  Future<void> refreshEngagementSchedules({
    required bool zipClearedToday,
    required bool pathWordsClearedToday,
    required bool sudokuClearedToday,
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
      final atRiskTonight =
          EngagementNotificationSchedule.shouldScheduleStreakAtRisk(
            zipClearedToday: zipClearedToday,
            pathWordsClearedToday: pathWordsClearedToday,
            sudokuClearedToday: sudokuClearedToday,
          );
      // With every game cleared nothing is at risk tonight, but the streak
      // is tomorrow, and only opening the app reschedules this; so remind
      // tomorrow evening rather than not at all. That one is a one-off: a
      // daily repeat can't start tomorrow (the plugin fires a repeat at the
      // next matching time, which would be tonight).
      await _client.scheduleNotification(
        id: NotificationTypes.scheduleIdStreakAtRisk,
        title: streakAtRiskTitle,
        body: streakAtRiskBody,
        when: atRiskTonight
            ? EngagementNotificationSchedule.nextDailyAtHour(
                NotificationTypes.streakAtRiskHour,
              )
            : EngagementNotificationSchedule.tomorrowAtHour(
                NotificationTypes.streakAtRiskHour,
              ),
        type: NotificationTypes.streakAtRisk,
        data: {'route': '/'},
        repeatsDaily: atRiskTonight,
      );
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
