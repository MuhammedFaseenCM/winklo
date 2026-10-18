import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/stats/clear_calendar.dart';

/// `year-month: sorted cleared days`, e.g. `2026-10: [1, 3]`.
List<String> _shape(List<ClearCalendarMonth> months) => [
  for (final m in months)
    '${m.year}-${m.month}: ${m.clearedDays.toList()..sort()}',
];

void main() {
  final today = DateTime(2026, 10, 15);

  test('no clears give no months', () {
    expect(clearCalendar(const [], today: today), isEmpty);
  });

  test('one month with its cleared days', () {
    final months = clearCalendar([
      DateTime(2026, 10, 3),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 3),
    ], today: today);
    expect(_shape(months), ['2026-10: [1, 3]']);
  });

  test('extends to the current month and keeps empty months', () {
    final months = clearCalendar([DateTime(2026, 7, 30)], today: today);
    expect(_shape(months), [
      '2026-7: [30]',
      '2026-8: []',
      '2026-9: []',
      '2026-10: []',
    ]);
  });

  test('crosses a year, oldest first', () {
    final months = clearCalendar([
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 1),
    ], today: DateTime(2027, 1, 2));
    expect(_shape(months), ['2026-12: [31]', '2027-1: [1]']);
  });

  test('a clear dated after today still shows', () {
    final months = clearCalendar([DateTime(2026, 11, 1)], today: today);
    expect(_shape(months), ['2026-11: [1]']);
  });

  group('ClearCalendarMonth', () {
    test('daysInMonth handles February in leap and common years', () {
      expect(const ClearCalendarMonth(year: 2024, month: 2).daysInMonth, 29);
      expect(const ClearCalendarMonth(year: 2026, month: 2).daysInMonth, 28);
      expect(const ClearCalendarMonth(year: 2026, month: 12).daysInMonth, 31);
      expect(const ClearCalendarMonth(year: 2026, month: 9).daysInMonth, 30);
    });

    test('leadingBlanks for Sunday- and Monday-first weeks', () {
      // 1 October 2026 is a Thursday; 1 March 2026 is a Sunday.
      const october = ClearCalendarMonth(year: 2026, month: 10);
      const march = ClearCalendarMonth(year: 2026, month: 3);
      expect(october.leadingBlanks(firstDayOfWeekIndex: 0), 4);
      expect(october.leadingBlanks(firstDayOfWeekIndex: 1), 3);
      expect(march.leadingBlanks(firstDayOfWeekIndex: 0), 0);
      expect(march.leadingBlanks(firstDayOfWeekIndex: 1), 6);
    });
  });
}
