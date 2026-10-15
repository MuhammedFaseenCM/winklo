import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/stats/clear_days.dart';

GameDayRecord _day(
  String playId, {
  int? time = 60,
  bool? usedHints,
  bool? hadMistakes,
  int hintsUsed = 0,
}) => GameDayRecord(
  gameId: GameIds.zip,
  playId: playId,
  timeSeconds: time,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  hintsUsed: hintsUsed,
);

void main() {
  group('dateOfPlayId', () {
    test('parses daily and debug ids to a local date', () {
      expect(dateOfPlayId('20261015'), DateTime(2026, 10, 15));
      expect(dateOfPlayId('202610152359'), DateTime(2026, 10, 15));
      expect(dateOfPlayId('20240229'), DateTime(2024, 2, 29));
    });

    test('rejects malformed ids', () {
      expect(dateOfPlayId(''), isNull);
      expect(dateOfPlayId('2026101'), isNull);
      expect(dateOfPlayId('2026-10-15'), isNull);
      expect(dateOfPlayId('20261015x'), isNull);
      expect(dateOfPlayId('20261315'), isNull);
      expect(dateOfPlayId('20261032'), isNull);
      expect(dateOfPlayId('20230229'), isNull);
    });
  });

  group('isHintFree', () {
    test('uses the flag when present', () {
      expect(
        isHintFree(_day('20261001', usedHints: false, hintsUsed: 2)),
        isTrue,
      );
      expect(isHintFree(_day('20261001', usedHints: true)), isFalse);
    });

    test('falls back to the hint count without a flag', () {
      expect(isHintFree(_day('20261001')), isTrue);
      expect(isHintFree(_day('20261001', hintsUsed: 1)), isFalse);
    });

    test('an uncleared day is never hint-free', () {
      expect(isHintFree(_day('20261001', time: null)), isFalse);
    });
  });

  group('isFlawless', () {
    test('needs no hints and no mistakes', () {
      expect(
        isFlawless(_day('20261001', usedHints: false, hadMistakes: false)),
        isTrue,
      );
      expect(
        isFlawless(_day('20261001', usedHints: false, hadMistakes: true)),
        isFalse,
      );
      expect(
        isFlawless(_day('20261001', usedHints: true, hadMistakes: false)),
        isFalse,
      );
    });

    test('unknown mistakes are not flawless', () {
      expect(isFlawless(_day('20261001', usedHints: false)), isFalse);
    });
  });

  group('longestDailyRun', () {
    test('is 0 for no days', () {
      expect(longestDailyRun(const []), 0);
    });

    test('is 1 for a single day', () {
      expect(longestDailyRun([DateTime(2026, 10, 1)]), 1);
    });

    test('counts across a month end and a year end', () {
      expect(
        longestDailyRun([
          DateTime(2026, 9, 29),
          DateTime(2026, 9, 30),
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
        ]),
        4,
      );
      expect(
        longestDailyRun([DateTime(2026, 12, 31), DateTime(2027, 1, 1)]),
        2,
      );
    });

    test('breaks on a gap and keeps the longest run', () {
      expect(
        longestDailyRun([
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 4),
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 6),
        ]),
        3,
      );
    });

    test('ignores duplicate dates and input order', () {
      expect(
        longestDailyRun([
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 2),
        ]),
        3,
      );
    });

    test('counts calendar days across a DST change', () {
      // Days are built at midnight, so a 23-hour day must still step by one.
      expect(
        longestDailyRun([
          DateTime(2026, 3, 28),
          DateTime(2026, 3, 29),
          DateTime(2026, 3, 30),
          DateTime(2026, 10, 24),
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 26),
          DateTime(2026, 10, 27),
        ]),
        4,
      );
    });
  });

  group('bestTimeByDate', () {
    test('keeps the fastest time per date and skips uncleared days', () {
      expect(
        bestTimeByDate([
          _day('202610010900', time: 90),
          _day('202610011000', time: 45),
          _day('20261002', time: 70),
          _day('20261003', time: null),
          _day('bad', time: 10),
        ]),
        {DateTime(2026, 10, 1): 45, DateTime(2026, 10, 2): 70},
      );
    });
  });
}
