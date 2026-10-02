import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/app_calendar.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/streak_calculator.dart';

void main() {
  group('AppCalendar', () {
    test('compact and dashed ids use local calendar day', () {
      final local = DateTime(2026, 10, 2, 1, 30);
      expect(AppCalendar.dateIdCompact(local), '20261002');
      expect(AppCalendar.dateIdDashed(local), '2026-10-02');
      expect(AppCalendar.calendarDay(local), DateTime(2026, 10, 2));
    });

    test('UTC instant maps through toLocal before Y/M/D', () {
      final utc = DateTime.utc(2026, 10, 1, 20, 0);
      final local = utc.toLocal();
      final expectedCompact =
          '${local.year.toString().padLeft(4, '0')}'
          '${local.month.toString().padLeft(2, '0')}'
          '${local.day.toString().padLeft(2, '0')}';
      final expectedDashed =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      expect(AppCalendar.dateIdCompact(utc), expectedCompact);
      expect(AppCalendar.dateIdDashed(utc), expectedDashed);
      expect(StreakCalculator.dateId(utc), expectedCompact);
      expect(PlayPeriod.id(utc, PlayPeriod.daily), expectedCompact);
      expect(leaderboardDayId(utc), expectedDashed);
    });
  });

  group('leaderboardDayId', () {
    test('formats local calendar day as yyyy-MM-dd', () {
      expect(leaderboardDayId(DateTime(2026, 9, 24, 23, 30)), '2026-09-24');
    });
  });
}
