import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/strings/app_strings.dart';
import '../../core/strings/app_text.dart';
import '../../domain/habit/engagement_reminder.dart';
import '../../domain/habit/shuffle_bag.dart';
import '../../domain/notification_types.dart';
import '../../domain/repositories/notification_repository.dart';
import '../clients/notification/notification_client.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required NotificationClient notificationClient,
    this._firestore,
    this._messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    bool Function()? announcementsEnabled,
    DateTime Function()? now,
  }) : _client = notificationClient,
       _now = now ?? DateTime.now,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _announcementsEnabled = announcementsEnabled ?? _always;

  final NotificationClient _client;
  final FirebaseFirestore? _firestore;
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// The player's announcements choice (Settings); read at each sync.
  final bool Function() _announcementsEnabled;

  static bool _always() => true;

  final DateTime Function() _now;

  static const _topicTimeout = Duration(seconds: 5);

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
      final topics = topicsForSync();
      for (final topic in topics) {
        await _client.subscribeToTopic(topic);
      }
      if (!topics.contains(NotificationTypes.topicAnnouncements)) {
        await _client.unsubscribeFromTopic(
          NotificationTypes.topicAnnouncements,
        );
      }
    } catch (e) {
      debugPrint('syncTokenForUser failed: $e');
    }
  }

  /// Topics a signed-in device joins: app updates always, announcements
  /// while they are on in Settings.
  @visibleForTesting
  List<String> topicsForSync() => [
    if (_announcementsEnabled()) NotificationTypes.topicAnnouncements,
    NotificationTypes.topicAppUpdates,
  ];

  @override
  Future<void> setAnnouncementsSubscribed(bool subscribed) async {
    try {
      final change = subscribed
          ? _client.subscribeToTopic(NotificationTypes.topicAnnouncements)
          : _client.unsubscribeFromTopic(NotificationTypes.topicAnnouncements);
      await change.timeout(_topicTimeout);
    } catch (e) {
      debugPrint('setAnnouncementsSubscribed($subscribed) failed: $e');
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
  Future<void> replaceEngagementSchedules(
    List<EngagementReminder> reminders,
  ) async {
    try {
      for (final id in NotificationTypes.engagementScheduleIds) {
        await _client.cancelNotification(id);
      }
    } catch (e) {
      debugPrint('replaceEngagementSchedules cancel failed: $e');
      return;
    }
    for (final reminder in reminders) {
      // The plan was made a moment ago; a reminder whose time has passed
      // since would be refused by the plugin.
      if (!reminder.when.isAfter(_now())) continue;
      final copy = engagementCopy(reminder);
      try {
        await _client.scheduleNotification(
          id: reminder.id,
          title: copy.title,
          body: copy.body,
          when: reminder.when,
          type: reminder.type,
          data: {'route': '/'},
        );
      } catch (e) {
        // One refused reminder must not drop the rest.
        debugPrint('schedule ${reminder.type} (${reminder.id}) failed: $e');
      }
    }
  }

  /// The words of [reminder]: a line from its pool, picked by
  /// [ShuffleBag] from the day it fires, so consecutive reminders differ.
  static NotifCopy engagementCopy(EngagementReminder reminder) {
    final day = ShuffleBag.epochDay(reminder.when);
    return switch (reminder) {
      DailyReadyReminder(
        phase: MorningPhase.active,
        :final streakGameId?,
        :final streakDays,
      )
          when day.isEven =>
        _pick(
          AppStrings.notifMorningStreakLines(streakGameId, streakDays),
          'morningStreak',
          day ~/ 2,
        ),
      DailyReadyReminder(:final phase) => _pick(
        switch (phase) {
          MorningPhase.active => AppStrings.notifMorningLines,
          MorningPhase.lapsed => AppStrings.notifLapsedLines,
          MorningPhase.missYou => AppStrings.notifMissYouLines,
          MorningPhase.lastCall => AppStrings.notifLastCallLines,
        },
        phase.name,
        day,
      ),
      StreakAtRiskReminder(:final gameId, :final days, :final others) => _pick(
        AppStrings.notifStreakRiskLines(gameId, days, others: others),
        'streakRisk',
        day,
      ),
      WeeklyRecapReminder(:final recap) => (
        title: _pick(
          AppStrings.notifWeeklyRecapTitles,
          'recap',
          day ~/ DateTime.daysPerWeek,
        ),
        body: AppStrings.weeklyRecapLine(recap),
      ),
    };
  }

  static T _pick<T>(List<T> pool, String key, int turn) =>
      pool[ShuffleBag.pick(key, turn, pool.length)];

  @override
  Stream<NotificationTap> watchTaps() {
    return _client.onNotificationTapped.map(
      (message) => NotificationTap(type: message.type, route: message.route),
    );
  }
}
