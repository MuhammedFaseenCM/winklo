import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/engagement_notification_schedule.dart';

void main() {
  group('EngagementNotificationSchedule.nextDailyAtHour', () {
    test('returns today when hour is still ahead', () {
      final now = DateTime(2026, 9, 24, 7, 30);
      final next = EngagementNotificationSchedule.nextDailyAtHour(8, now: now);
      expect(next, DateTime(2026, 9, 24, 8));
    });

    test('returns tomorrow when hour already passed', () {
      final now = DateTime(2026, 9, 24, 20, 1);
      final next = EngagementNotificationSchedule.nextDailyAtHour(20, now: now);
      expect(next, DateTime(2026, 9, 25, 20));
    });
  });

  group('EngagementNotificationSchedule.tomorrowAtHour', () {
    test('is the next day even before the hour', () {
      final now = DateTime(2026, 9, 24, 7, 30);
      expect(
        EngagementNotificationSchedule.tomorrowAtHour(20, now: now),
        DateTime(2026, 9, 25, 20),
      );
    });

    test('rolls over the end of a month', () {
      final now = DateTime(2026, 9, 30, 23, 59);
      expect(
        EngagementNotificationSchedule.tomorrowAtHour(20, now: now),
        DateTime(2026, 10, 1, 20),
      );
    });
  });

  group('shouldScheduleStreakAtRisk', () {
    test('true when any game uncleared', () {
      expect(
        EngagementNotificationSchedule.shouldScheduleStreakAtRisk(
          zipClearedToday: true,
          pathWordsClearedToday: true,
          sudokuClearedToday: false,
        ),
        isTrue,
      );
    });

    test('false when all cleared', () {
      expect(
        EngagementNotificationSchedule.shouldScheduleStreakAtRisk(
          zipClearedToday: true,
          pathWordsClearedToday: true,
          sudokuClearedToday: true,
        ),
        isFalse,
      );
    });
  });
}
