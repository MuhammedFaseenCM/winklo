import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/data/clients/notification/notification_client.dart';
import 'package:winklo/data/repositories/notification_repository_impl.dart';
import 'package:winklo/domain/engagement_notification_schedule.dart';
import 'package:winklo/domain/notification_types.dart';

class _MockClient extends Mock implements NotificationClient {}

class _MockLocalNotifications extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late _MockClient client;
  late NotificationRepositoryImpl repo;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    client = _MockClient();
    when(() => client.cancelNotification(any())).thenAnswer((_) async {});
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
    );
  });

  Future<List<dynamic>> streakReminder({required bool sudokuCleared}) async {
    await repo.refreshEngagementSchedules(
      zipClearedToday: true,
      pathWordsClearedToday: true,
      sudokuClearedToday: sudokuCleared,
      dailyReadyTitle: 'ready',
      dailyReadyBody: 'ready',
      streakAtRiskTitle: 'risk',
      streakAtRiskBody: 'risk',
    );
    return verify(
      () => client.scheduleNotification(
        id: NotificationTypes.scheduleIdStreakAtRisk,
        title: any(named: 'title'),
        body: any(named: 'body'),
        when: captureAny(named: 'when'),
        data: any(named: 'data'),
        type: any(named: 'type'),
        repeatsDaily: captureAny(named: 'repeatsDaily'),
      ),
    ).captured;
  }

  test('with a game still to play, reminds daily from tonight', () async {
    final captured = await streakReminder(sudokuCleared: false);
    expect(
      captured[0],
      EngagementNotificationSchedule.nextDailyAtHour(
        NotificationTypes.streakAtRiskHour,
      ),
    );
    expect(captured[1], isTrue);
  });

  test(
    'with every game cleared, still reminds tomorrow evening (once)',
    () async {
      final captured = await streakReminder(sudokuCleared: true);
      expect(
        captured[0],
        EngagementNotificationSchedule.tomorrowAtHour(
          NotificationTypes.streakAtRiskHour,
        ),
      );
      expect(captured[1], isFalse);
    },
  );
}
