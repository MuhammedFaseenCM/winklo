import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/archive_calendar.dart';

void main() {
  test('runs from 11 Oct 2026 to yesterday', () {
    final months = archiveMonths(
      now: DateTime(2026, 10, 15, 8),
      isCleared: (_) => false,
    );
    expect(months, [
      const ArchiveMonth(year: 2026, month: 10, firstDay: 11, lastDay: 14),
    ]);
    expect(months.single.isPlayable(10), isFalse);
    expect(months.single.isPlayable(11), isTrue);
    expect(months.single.isPlayable(14), isTrue);
    expect(months.single.isPlayable(15), isFalse);
  });

  test('pages over months and years', () {
    final months = archiveMonths(
      now: DateTime(2027, 1, 3),
      isCleared: (_) => false,
    );
    expect(months.map((m) => '${m.year}-${m.month}'), [
      '2026-10',
      '2026-11',
      '2026-12',
      '2027-1',
    ]);
    expect(months[1].firstDay, 1);
    expect(months[1].lastDay, 30);
    expect(months.last.lastDay, 2);
  });

  test('marks the days isCleared says, only inside the archive', () {
    final cleared = {DateTime(2026, 10, 9), DateTime(2026, 10, 12)};
    final months = archiveMonths(
      now: DateTime(2026, 10, 15),
      isCleared: cleared.contains,
    );
    expect(months.single.clearedDays, {12});
  });

  test('is empty before the archive starts', () {
    expect(
      archiveMonths(now: DateTime(2026, 10, 11, 23), isCleared: (_) => true),
      isEmpty,
    );
  });

  test('leading blanks follow the first day of the week', () {
    // 1 Oct 2026 is a Thursday.
    const month = ArchiveMonth(
      year: 2026,
      month: 10,
      firstDay: 11,
      lastDay: 31,
    );
    expect(month.leadingBlanks(firstDayOfWeekIndex: 0), 4);
    expect(month.leadingBlanks(firstDayOfWeekIndex: 1), 3);
  });
}
