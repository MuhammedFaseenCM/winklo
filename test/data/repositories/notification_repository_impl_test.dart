import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/clients/notification/notification_client.dart';
import 'package:winklo/data/repositories/notification_repository_impl.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/habit/engagement_reminder.dart';
import 'package:winklo/domain/habit/weekly_recap.dart';
import 'package:winklo/domain/notification_types.dart';

class _MockClient extends Mock implements NotificationClient {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late _MockClient client;
  late NotificationRepositoryImpl repo;
  late bool announcements;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    client = _MockClient();
    announcements = true;
    when(() => client.cancelNotification(any())).thenAnswer((_) async {});
    when(() => client.subscribeToTopic(any())).thenAnswer((_) async {});
    when(() => client.unsubscribeFromTopic(any())).thenAnswer((_) async {});
    when(
      () => client.scheduleNotification(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        when: any(named: 'when'),
        data: any(named: 'data'),
        type: any(named: 'type'),
        repeatsDaily: any(named: 'repeatsDaily'),
      ),
    ).thenAnswer((_) async {});
    repo = NotificationRepositoryImpl(
      notificationClient: client,
      localNotifications: _MockLocalNotifications(),
      announcementsEnabled: () => announcements,
    );
  });

  group('replaceEngagementSchedules', () {
    test('cancels every engagement id, then schedules each reminder', () async {
      final at = DateTime(2026, 10, 15, 20);
      await repo.replaceEngagementSchedules([
        StreakAtRiskReminder(
          when: at,
          id: NotificationTypes.scheduleIdStreakAtRisk,
          gameId: GameIds.zip,
          days: 12,
          others: 2,
        ),
      ]);

      for (final id in NotificationTypes.engagementScheduleIds) {
        verify(() => client.cancelNotification(id)).called(1);
      }
      verify(
        () => client.scheduleNotification(
          id: NotificationTypes.scheduleIdStreakAtRisk,
          title: AppStrings.notifStreakAtRiskTitle,
          body: 'Your 12-day Zip streak and 2 more end at midnight',
          when: at,
          data: {'route': '/'},
          type: NotificationTypes.streakAtRisk,
          repeatsDaily: false,
        ),
      ).called(1);
    });

    test('an empty plan only cancels', () async {
      await repo.replaceEngagementSchedules(const []);
      verify(() => client.cancelNotification(any())).called(4);
      verifyNever(
        () => client.scheduleNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          when: any(named: 'when'),
          data: any(named: 'data'),
          type: any(named: 'type'),
          repeatsDaily: any(named: 'repeatsDaily'),
        ),
      );
    });

    test('daily ready repeats with the ready copy', () async {
      final at = DateTime(2026, 10, 16, 8);
      await repo.replaceEngagementSchedules([DailyReadyReminder(when: at)]);
      verify(
        () => client.scheduleNotification(
          id: NotificationTypes.scheduleIdDailyReady,
          title: AppStrings.notifDailyReadyTitle,
          body: AppStrings.notifDailyReadyBody,
          when: at,
          data: {'route': '/'},
          type: NotificationTypes.dailyReady,
          repeatsDaily: true,
        ),
      ).called(1);
    });

    test('the weekly recap uses the recap line', () async {
      final at = DateTime(2026, 10, 18, 19);
      const recap = WeeklyRecap(
        weekStartId: '20261012',
        cleared: 18,
        possible: 21,
        bestGameId: GameIds.zip,
        bestSeconds: 58,
      );
      await repo.replaceEngagementSchedules([
        WeeklyRecapReminder(when: at, recap: recap),
      ]);
      verify(
        () => client.scheduleNotification(
          id: NotificationTypes.scheduleIdWeeklyRecap,
          title: AppStrings.notifWeeklyRecapTitle,
          body: 'This week: 18 of 21 cleared, best Zip 0:58',
          when: at,
          data: {'route': '/'},
          type: NotificationTypes.weeklyRecap,
          repeatsDaily: false,
        ),
      ).called(1);
    });

    test('a failing client never throws', () async {
      when(
        () => client.cancelNotification(any()),
      ).thenThrow(StateError('no plugin'));
      await expectLater(
        repo.replaceEngagementSchedules([
          DailyReadyReminder(when: DateTime(2026, 10, 16, 8)),
        ]),
        completes,
      );
    });
  });

  group('announcements topic', () {
    test('setAnnouncementsSubscribed subscribes and unsubscribes', () async {
      await repo.setAnnouncementsSubscribed(true);
      verify(
        () => client.subscribeToTopic(NotificationTypes.topicAnnouncements),
      ).called(1);
      await repo.setAnnouncementsSubscribed(false);
      verify(
        () => client.unsubscribeFromTopic(NotificationTypes.topicAnnouncements),
      ).called(1);
    });

    test('topicsForSync leaves announcements out when they are off', () {
      expect(repo.topicsForSync(), [
        NotificationTypes.topicAnnouncements,
        NotificationTypes.topicAppUpdates,
      ]);
      announcements = false;
      expect(repo.topicsForSync(), [NotificationTypes.topicAppUpdates]);
    });
  });
}
