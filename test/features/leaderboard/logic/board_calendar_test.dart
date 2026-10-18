import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/features/leaderboard/logic/board_calendar.dart';

void main() {
  group('boardCalendarWeeks', () {
    test('Saturday 17 Oct 2026: three Monday-first weeks', () {
      final days = recentLeaderboardDayIds(DateTime(2026, 10, 17, 9));
      final weeks = boardCalendarWeeks(days);

      expect(weeks, hasLength(3));
      expect(weeks.every((w) => w.length == 7), isTrue);
      expect(weeks.first.first.dayId, '2026-09-28');
      expect(weeks.first.first.inWindow, isFalse);
      expect(weeks.first.last.dayId, '2026-10-04');
      expect(weeks.first.last.inWindow, isTrue);
      expect(weeks.last[5].dayId, '2026-10-17');
      expect(weeks.last[5].inWindow, isTrue);
      expect(weeks.last.last.dayId, '2026-10-18');
      expect(weeks.last.last.inWindow, isFalse);
      expect(
        weeks.expand((w) => w).where((d) => d.inWindow).map((d) => d.dayId),
        unorderedEquals(days),
      );
    });

    test('a Monday today: three rows, today first in the last', () {
      final weeks = boardCalendarWeeks(
        recentLeaderboardDayIds(DateTime(2026, 10, 19, 9)),
      );
      expect(weeks, hasLength(3));
      expect(weeks.last.first.dayId, '2026-10-19');
      expect(weeks.last.first.inWindow, isTrue);
      expect(weeks.last.skip(1).every((d) => !d.inWindow), isTrue);
    });

    test('a Sunday today: exactly two full weeks', () {
      final weeks = boardCalendarWeeks(
        recentLeaderboardDayIds(DateTime(2026, 10, 18, 9)),
      );
      expect(weeks, hasLength(2));
      expect(weeks.expand((w) => w).every((d) => d.inWindow), isTrue);
    });

    test('crosses a year boundary', () {
      final weeks = boardCalendarWeeks(
        recentLeaderboardDayIds(DateTime(2027, 1, 3, 9)),
      );
      expect(weeks.first.first.dayId, '2026-12-21');
      expect(weeks.last.last.dayId, '2027-01-03');
      expect(weeks.last.last.dayOfMonth, 3);
    });

    test('no days, no weeks', () {
      expect(boardCalendarWeeks(const []), isEmpty);
    });
  });

  group('labels', () {
    final days = recentLeaderboardDayIds(DateTime(2026, 10, 17, 9));

    test('day label: Today, Yesterday, then a short date', () {
      expect(leaderboardDayLabel(days[0], 0), AppStrings.leaderboardToday);
      expect(leaderboardDayLabel(days[1], 1), AppStrings.leaderboardYesterday);
      expect(
        leaderboardDayLabel('2026-10-14', 3),
        AppStrings.leaderboardShortDate(14, 10),
      );
    });

    test('board label follows the period and day', () {
      String label(LeaderboardPeriod p, [String? day]) =>
          leaderboardBoardLabel(period: p, dayId: day, recentDayIds: days);

      expect(label(LeaderboardPeriod.daily), AppStrings.leaderboardToday);
      expect(
        label(LeaderboardPeriod.daily, '2026-10-16'),
        AppStrings.leaderboardYesterday,
      );
      expect(
        label(LeaderboardPeriod.daily, '2026-10-12'),
        AppStrings.leaderboardShortDate(12, 10),
      );
      expect(label(LeaderboardPeriod.weekly), AppStrings.leaderboardThisWeek);
      expect(label(LeaderboardPeriod.allTime), AppStrings.leaderboardAllTime);
    });
  });
}
