import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/engagement_notification_schedule.dart';

void main() {
  group('EngagementNotificationSchedule.nextDailyAt', () {
    test('returns today when the time is still ahead', () {
      final now = DateTime(2026, 9, 24, 7, 30);
      expect(
        EngagementNotificationSchedule.nextDailyAt(8 * 60, now: now),
        DateTime(2026, 9, 24, 8),
      );
    });

    test('returns tomorrow when the time already passed', () {
      final now = DateTime(2026, 9, 24, 20, 1);
      expect(
        EngagementNotificationSchedule.nextDailyAt(20 * 60, now: now),
        DateTime(2026, 9, 25, 20),
      );
    });

    test('exactly now counts as passed', () {
      final now = DateTime(2026, 9, 24, 20);
      expect(
        EngagementNotificationSchedule.nextDailyAt(20 * 60, now: now),
        DateTime(2026, 9, 25, 20),
      );
    });

    test('keeps the minutes', () {
      final now = DateTime(2026, 9, 24, 7, 30);
      expect(
        EngagementNotificationSchedule.nextDailyAt(21 * 60 + 45, now: now),
        DateTime(2026, 9, 24, 21, 45),
      );
    });
  });

  group('EngagementNotificationSchedule.atMinutes', () {
    test('is that day at the time, rolling months over', () {
      expect(
        EngagementNotificationSchedule.atMinutes(
          DateTime(2026, 9, 30, 23, 59),
          20 * 60,
          dayOffset: 1,
        ),
        DateTime(2026, 10, 1, 20),
      );
      expect(
        EngagementNotificationSchedule.atMinutes(
          DateTime(2026, 9, 30, 23, 59),
          8 * 60 + 5,
        ),
        DateTime(2026, 9, 30, 8, 5),
      );
    });
  });

  group('EngagementNotificationSchedule.nextWeekdayAt', () {
    test('this Sunday when it is ahead', () {
      // Thursday 15 October 2026.
      final now = DateTime(2026, 10, 15, 12);
      expect(
        EngagementNotificationSchedule.nextWeekdayAt(
          DateTime.sunday,
          19 * 60,
          now: now,
        ),
        DateTime(2026, 10, 18, 19),
      );
    });

    test('today when it is Sunday before the time', () {
      final now = DateTime(2026, 10, 18, 10);
      expect(
        EngagementNotificationSchedule.nextWeekdayAt(
          DateTime.sunday,
          19 * 60,
          now: now,
        ),
        DateTime(2026, 10, 18, 19),
      );
    });

    test('next week when it is Sunday after the time', () {
      final now = DateTime(2026, 10, 18, 19, 30);
      expect(
        EngagementNotificationSchedule.nextWeekdayAt(
          DateTime.sunday,
          19 * 60,
          now: now,
        ),
        DateTime(2026, 10, 25, 19),
      );
    });
  });
}
