import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/iso_week.dart';

void main() {
  // The same days as isoWeekId in workers/leaderboard/src/days.test.ts.
  const cases = {
    '2026-01-01': '2026-W01',
    '2026-10-12': '2026-W42',
    '2026-10-15': '2026-W42',
    '2026-10-18': '2026-W42',
    '2026-10-19': '2026-W43',
    '2027-01-01': '2026-W53',
    '2024-12-30': '2025-W01',
    '2021-01-03': '2020-W53',
  };

  for (final MapEntry(key: day, value: week) in cases.entries) {
    test('$day is in $week', () {
      expect(isoWeekIdForDayId(day), week);
    });
  }

  test('refuses a day that is not yyyy-MM-dd', () {
    expect(() => isoWeekIdForDayId('20261015'), throwsArgumentError);
  });

  test('lists Monday…Sunday for the week holding a day', () {
    expect(dayIdsInIsoWeekContaining('2026-10-15'), [
      '2026-10-12',
      '2026-10-13',
      '2026-10-14',
      '2026-10-15',
      '2026-10-16',
      '2026-10-17',
      '2026-10-18',
    ]);
    expect(dayIdsInIsoWeekContaining('2026-10-12').first, '2026-10-12');
  });
}
