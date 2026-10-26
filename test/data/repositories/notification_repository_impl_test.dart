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
      ),
    ).thenAnswer((_) async {});
    repo = NotificationRepositoryImpl(
      notificationClient: client,
      localNotifications: _MockLocalNotifications(),
      announcementsEnabled: () => announcements,
      now: () => DateTime(2026, 10, 15, 9),
    );
  });

  ({String title, String body}) scheduled(int id) {
    final call = verify(
      () => client.scheduleNotification(
        id: id,
        title: captureAny(named: 'title'),
        body: captureAny(named: 'body'),
        when: any(named: 'when'),
        data: any(named: 'data'),
        type: any(named: 'type'),
      ),
    )..called(1);
    return (
      title: call.captured[0] as String,
      body: call.captured[1] as String,
    );
  }

  DailyReadyReminder morning(
    DateTime when, {
    int slot = 0,
    MorningPhase phase = MorningPhase.active,
    String? streakGameId,
    int streakDays = 0,
  }) => DailyReadyReminder(
    when: when,
    slot: slot,
    phase: phase,
    streakGameId: streakGameId,
    streakDays: streakDays,
  );

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
          title: any(named: 'title'),
          body: any(named: 'body'),
          when: at,
          data: {'route': '/'},
          type: NotificationTypes.streakAtRisk,
        ),
      ).called(1);
    });

    test('replans cancel the daily repeat of older builds', () async {
      await repo.replaceEngagementSchedules(const []);
      verify(
        () => client.cancelNotification(
          NotificationTypes.scheduleIdDailyReadyLegacy,
        ),
      ).called(1);
    });

    test('an empty plan only cancels', () async {
      await repo.replaceEngagementSchedules(const []);
      verify(
        () => client.cancelNotification(any()),
      ).called(NotificationTypes.engagementScheduleIds.length);
      verifyNever(
        () => client.scheduleNotification(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          when: any(named: 'when'),
          data: any(named: 'data'),
          type: any(named: 'type'),
        ),
      );
    });

    test('a morning is a one-off with a line from its pool', () async {
      final at = DateTime(2026, 10, 16, 8);
      await repo.replaceEngagementSchedules([morning(at)]);
      final call = verify(
        () => client.scheduleNotification(
          id: NotificationTypes.scheduleIdMorningBase,
          title: captureAny(named: 'title'),
          body: captureAny(named: 'body'),
          when: at,
          data: {'route': '/'},
          type: NotificationTypes.dailyReady,
        ),
      )..called(1);
      expect(
        AppStrings.notifMorningLines,
        contains((
          title: call.captured[0] as String,
          body: call.captured[1] as String,
        )),
      );
    });

    test('each phase draws from its own pool', () async {
      final pools = {
        MorningPhase.lapsed: AppStrings.notifLapsedLines,
        MorningPhase.missYou: AppStrings.notifMissYouLines,
        MorningPhase.lastCall: AppStrings.notifLastCallLines,
      };
      var slot = 1;
      for (final MapEntry(key: phase, value: pool) in pools.entries) {
        await repo.replaceEngagementSchedules([
          morning(DateTime(2026, 10, 16 + slot, 8), slot: slot, phase: phase),
        ]);
        final copy = scheduled(NotificationTypes.scheduleIdMorningBase + slot);
        expect(pool, contains(copy), reason: phase.name);
        slot++;
      }
    });

    test('a named streak shows on every other active morning', () async {
      final copies = [
        for (final day in [16, 17])
          NotificationRepositoryImpl.engagementCopy(
            morning(
              DateTime(2026, 10, day, 8),
              streakGameId: GameIds.sudoku,
              streakDays: 9,
            ),
          ),
      ];
      final streakLines = AppStrings.notifMorningStreakLines(GameIds.sudoku, 9);
      expect(
        copies.where(streakLines.contains),
        hasLength(1),
        reason: 'one of two days uses the streak lines',
      );
      expect(copies.where(AppStrings.notifMorningLines.contains), hasLength(1));
    });

    test('no two mornings in a row share a line', () {
      final days = 2 * AppStrings.notifMorningLines.length + 1;
      final copies = [
        for (var i = 0; i < days; i++)
          NotificationRepositoryImpl.engagementCopy(
            morning(DateTime(2026, 10, 16 + i, 8)),
          ),
      ];
      for (var i = 1; i < days; i++) {
        expect(copies[i], isNot(copies[i - 1]), reason: 'day $i');
      }
      // A pass of the shuffle bag uses every line.
      expect(copies.toSet(), hasLength(AppStrings.notifMorningLines.length));
    });

    test('a streak at risk names the game and its days', () {
      final copy = NotificationRepositoryImpl.engagementCopy(
        StreakAtRiskReminder(
          when: DateTime(2026, 10, 15, 20),
          id: NotificationTypes.scheduleIdStreakAtRisk,
          gameId: GameIds.pathWords,
          days: 12,
          others: 2,
        ),
      );
      expect(
        AppStrings.notifStreakRiskLines(GameIds.pathWords, 12, others: 2),
        contains(copy),
      );
      expect('${copy.title} ${copy.body}', contains('Path Words'));
      expect(copy.body, endsWith('2 more streaks end tonight too.'));
    });

    test('tonight and tomorrow evening read differently', () {
      ({String title, String body}) evening(int day) =>
          NotificationRepositoryImpl.engagementCopy(
            StreakAtRiskReminder(
              when: DateTime(2026, 10, day, 20),
              id: NotificationTypes.scheduleIdStreakAtRisk,
              gameId: GameIds.zip,
              days: 12,
            ),
          );
      expect(evening(15), isNot(evening(16)));
    });

    test('the weekly recap rotates its title over the recap line', () async {
      const recap = WeeklyRecap(
        weekStartId: '20261012',
        cleared: 18,
        possible: 21,
        bestGameId: GameIds.zip,
        bestSeconds: 58,
      );
      await repo.replaceEngagementSchedules([
        WeeklyRecapReminder(when: DateTime(2026, 10, 18, 19), recap: recap),
      ]);
      final copy = scheduled(NotificationTypes.scheduleIdWeeklyRecap);
      expect(AppStrings.notifWeeklyRecapTitles, contains(copy.title));
      expect(copy.body, 'This week: 18 of 21 cleared, best Zip 0:58');

      final nextWeek = NotificationRepositoryImpl.engagementCopy(
        WeeklyRecapReminder(when: DateTime(2026, 10, 25, 19), recap: recap),
      );
      expect(nextWeek.title, isNot(copy.title));
    });

    test('a reminder whose time has passed is skipped', () async {
      // Planning ran before 20:00; scheduling happens after it.
      repo = NotificationRepositoryImpl(
        notificationClient: client,
        localNotifications: _MockLocalNotifications(),
        now: () => DateTime(2026, 10, 15, 20, 0, 1),
      );
      await repo.replaceEngagementSchedules([
        StreakAtRiskReminder(
          when: DateTime(2026, 10, 15, 20),
          id: NotificationTypes.scheduleIdStreakAtRisk,
          gameId: GameIds.zip,
          days: 3,
        ),
        morning(DateTime(2026, 10, 15, 20)),
        morning(
          DateTime(2026, 10, 16, 20),
          slot: 1,
          phase: MorningPhase.lapsed,
        ),
      ]);
      for (final id in [
        NotificationTypes.scheduleIdStreakAtRisk,
        NotificationTypes.scheduleIdMorningBase,
      ]) {
        verifyNever(
          () => client.scheduleNotification(
            id: id,
            title: any(named: 'title'),
            body: any(named: 'body'),
            when: any(named: 'when'),
            data: any(named: 'data'),
            type: any(named: 'type'),
          ),
        );
      }
      scheduled(NotificationTypes.scheduleIdMorningBase + 1);
    });

    test('one failing schedule does not drop the others', () async {
      when(
        () => client.scheduleNotification(
          id: NotificationTypes.scheduleIdStreakAtRisk,
          title: any(named: 'title'),
          body: any(named: 'body'),
          when: any(named: 'when'),
          data: any(named: 'data'),
          type: any(named: 'type'),
        ),
      ).thenThrow(ArgumentError('Must be a date in the future'));
      final recapAt = DateTime(2026, 10, 18, 19);
      await repo.replaceEngagementSchedules([
        StreakAtRiskReminder(
          when: DateTime(2026, 10, 15, 20),
          id: NotificationTypes.scheduleIdStreakAtRisk,
          gameId: GameIds.zip,
          days: 3,
        ),
        WeeklyRecapReminder(
          when: recapAt,
          recap: const WeeklyRecap(
            weekStartId: '20261012',
            cleared: 2,
            possible: 21,
          ),
        ),
      ]);
      verify(
        () => client.scheduleNotification(
          id: NotificationTypes.scheduleIdWeeklyRecap,
          title: any(named: 'title'),
          body: any(named: 'body'),
          when: recapAt,
          data: any(named: 'data'),
          type: any(named: 'type'),
        ),
      ).called(1);
    });

    test('a failing client never throws', () async {
      when(
        () => client.cancelNotification(any()),
      ).thenThrow(StateError('no plugin'));
      await expectLater(
        repo.replaceEngagementSchedules([morning(DateTime(2026, 10, 16, 8))]),
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
