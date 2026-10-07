import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/app_calendar.dart';
import 'package:winklo/domain/entities/clear_meta.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/logic/progress_merge.dart';
import 'package:winklo/domain/play_period.dart';

GameDayRecord _day({
  int? time,
  int? points,
  bool? usedHints,
  bool? hadMistakes,
  bool? flagsKnown,
  int hintsUsed = 0,
  DateTime? clearedAt,
  String gameId = GameIds.zip,
  String playId = '20261007',
}) => GameDayRecord(
  gameId: gameId,
  playId: playId,
  timeSeconds: time,
  points: points,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  flagsKnown: flagsKnown,
  hintsUsed: hintsUsed,
  clearedAt: clearedAt,
);

GameStreak _streak({
  int current = 0,
  int longest = 0,
  String? last,
  bool freeze = true,
  String gameId = GameIds.zip,
}) => GameStreak(
  gameId: gameId,
  current: current,
  longest: longest,
  lastClearedDateId: last,
  freezeAvailable: freeze,
);

void main() {
  group('mergeGameDay', () {
    test('null remote returns local unchanged', () {
      final local = _day(time: 20, points: 900, usedHints: false);
      expect(mergeGameDay(local, null), local);
    });

    test('takes min time, max points, and flags from the faster side', () {
      final local = _day(
        time: 30,
        points: 800,
        usedHints: true,
        hadMistakes: true,
        flagsKnown: true,
      );
      final remote = _day(
        time: 20,
        points: 700,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: false,
      );
      final merged = mergeGameDay(local, remote);
      expect(merged.timeSeconds, 20);
      expect(merged.points, 800);
      expect(merged.usedHints, isFalse);
      expect(merged.hadMistakes, isFalse);
      expect(merged.flagsKnown, isFalse);
    });

    test('faster local keeps local flags', () {
      final local = _day(
        time: 10,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      );
      final remote = _day(
        time: 11,
        usedHints: true,
        hadMistakes: true,
        flagsKnown: true,
      );
      final merged = mergeGameDay(local, remote);
      expect(merged.timeSeconds, 10);
      expect(merged.usedHints, isFalse);
      expect(merged.hadMistakes, isFalse);
    });

    test('time tie prefers the side with known flags', () {
      final local = _day(
        time: 15,
        usedHints: true,
        hadMistakes: true,
        flagsKnown: false,
      );
      final remote = _day(
        time: 15,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      );
      final merged = mergeGameDay(local, remote);
      expect(merged.usedHints, isFalse);
      expect(merged.hadMistakes, isFalse);
      expect(merged.flagsKnown, isTrue);
    });

    test('time tie with null vs false flagsKnown still prefers local', () {
      final local = _day(time: 15, usedHints: true, hadMistakes: false);
      final remote = _day(
        time: 15,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: false,
      );
      final merged = mergeGameDay(local, remote);
      expect(merged.usedHints, isTrue);
      expect(merged.flagsKnown, isNull);
    });

    test('time tie with both known prefers local', () {
      final local = _day(
        time: 15,
        usedHints: true,
        hadMistakes: false,
        flagsKnown: true,
      );
      final remote = _day(
        time: 15,
        usedHints: false,
        hadMistakes: true,
        flagsKnown: true,
      );
      final merged = mergeGameDay(local, remote);
      expect(merged.usedHints, isTrue);
      expect(merged.hadMistakes, isFalse);
    });

    test('time tie with both unknown prefers local', () {
      final local = _day(
        time: 15,
        usedHints: true,
        hadMistakes: true,
        flagsKnown: false,
      );
      final remote = _day(
        time: 15,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: false,
      );
      expect(mergeGameDay(local, remote).usedHints, isTrue);
    });

    test('only remote cleared: remote time and flags win', () {
      final local = _day(hintsUsed: 1);
      final remote = _day(
        time: 42,
        points: 600,
        usedHints: true,
        hadMistakes: false,
        flagsKnown: true,
        hintsUsed: 2,
      );
      final merged = mergeGameDay(local, remote);
      expect(merged.cleared, isTrue);
      expect(merged.timeSeconds, 42);
      expect(merged.points, 600);
      expect(merged.usedHints, isTrue);
      expect(merged.hadMistakes, isFalse);
      expect(merged.flagsKnown, isTrue);
      expect(merged.hintsUsed, 2);
    });

    test('only local cleared: local time and flags win', () {
      final local = _day(
        time: 42,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
      );
      final remote = _day(hintsUsed: 3);
      final merged = mergeGameDay(local, remote);
      expect(merged.timeSeconds, 42);
      expect(merged.usedHints, isFalse);
      expect(merged.flagsKnown, isTrue);
      expect(merged.hintsUsed, 3);
    });

    test('neither cleared: no time, max hints, local flags', () {
      final merged = mergeGameDay(
        _day(hintsUsed: 2),
        _day(hintsUsed: 1, points: 5),
      );
      expect(merged.cleared, isFalse);
      expect(merged.timeSeconds, isNull);
      expect(merged.points, 5);
      expect(merged.hintsUsed, 2);
      expect(merged.usedHints, isNull);
    });

    test('points ignore nulls on either side', () {
      expect(mergeGameDay(_day(points: 3), _day()).points, 3);
      expect(mergeGameDay(_day(), _day(points: 4)).points, 4);
      expect(mergeGameDay(_day(), _day()).points, isNull);
    });

    test('clearedAt is the earliest non-null', () {
      final early = DateTime.utc(2026, 10, 7, 8);
      final late = DateTime.utc(2026, 10, 7, 9);
      expect(
        mergeGameDay(_day(clearedAt: late), _day(clearedAt: early)).clearedAt,
        early,
      );
      expect(
        mergeGameDay(_day(clearedAt: early), _day(clearedAt: late)).clearedAt,
        early,
      );
      expect(mergeGameDay(_day(), _day(clearedAt: late)).clearedAt, late);
      expect(mergeGameDay(_day(clearedAt: early), _day()).clearedAt, early);
      expect(mergeGameDay(_day(), _day()).clearedAt, isNull);
    });

    test('keeps local ids', () {
      final merged = mergeGameDay(
        _day(gameId: GameIds.sudoku, playId: '20261006'),
        _day(gameId: GameIds.sudoku, playId: '20261006', time: 3),
      );
      expect(merged.gameId, GameIds.sudoku);
      expect(merged.playId, '20261006');
    });

    test('is idempotent', () {
      final local = _day(time: 30, points: 10, usedHints: true, hintsUsed: 1);
      final remote = _day(time: 20, points: 20, hadMistakes: false);
      final once = mergeGameDay(local, remote);
      expect(mergeGameDay(once, remote), once);
    });
  });

  group('mergeStreak', () {
    test('null remote returns local', () {
      final local = _streak(current: 2, longest: 4, last: '20261006');
      expect(identical(mergeStreak(local, null), local), isTrue);
    });

    test('later lastClearedDateId wins', () {
      final local = _streak(
        current: 5,
        longest: 9,
        last: '20261005',
        freeze: true,
      );
      final remote = _streak(
        current: 2,
        longest: 3,
        last: '20261007',
        freeze: false,
      );
      final merged = mergeStreak(local, remote);
      expect(merged.current, 2);
      expect(merged.lastClearedDateId, '20261007');
      expect(merged.freezeAvailable, isFalse);
      expect(merged.longest, 9);
    });

    test('later local wins over remote', () {
      final merged = mergeStreak(
        _streak(current: 1, longest: 1, last: '20261007', freeze: false),
        _streak(current: 6, longest: 6, last: '20261006'),
      );
      expect(merged.current, 1);
      expect(merged.lastClearedDateId, '20261007');
      expect(merged.freezeAvailable, isFalse);
      expect(merged.longest, 6);
    });

    test('null lastClearedDateId is oldest', () {
      final merged = mergeStreak(
        _streak(current: 0, longest: 7),
        _streak(current: 1, longest: 1, last: '20200101'),
      );
      expect(merged.current, 1);
      expect(merged.lastClearedDateId, '20200101');
      expect(merged.longest, 7);

      final reverse = mergeStreak(
        _streak(current: 1, longest: 1, last: '20200101'),
        _streak(current: 0, longest: 2),
      );
      expect(reverse.lastClearedDateId, '20200101');
      expect(reverse.longest, 2);
    });

    test('same day tie goes to higher current', () {
      final merged = mergeStreak(
        _streak(current: 2, longest: 2, last: '20261007', freeze: true),
        _streak(current: 4, longest: 4, last: '20261007', freeze: false),
      );
      expect(merged.current, 4);
      expect(merged.freezeAvailable, isFalse);
      expect(merged.longest, 4);
    });

    test('full tie prefers local', () {
      final merged = mergeStreak(
        _streak(current: 3, longest: 3, last: '20261007', freeze: true),
        _streak(current: 3, longest: 3, last: '20261007', freeze: false),
      );
      expect(merged.freezeAvailable, isTrue);
    });

    test('both empty prefers local freeze', () {
      final merged = mergeStreak(_streak(freeze: false), _streak(freeze: true));
      expect(merged.current, 0);
      expect(merged.lastClearedDateId, isNull);
      expect(merged.freezeAvailable, isFalse);
    });

    test('longest is raised to the winning current', () {
      final merged = mergeStreak(
        _streak(current: 1, longest: 1, last: '20261001'),
        _streak(current: 8, longest: 2, last: '20261007'),
      );
      expect(merged.longest, 8);
    });

    test('keeps local gameId and never reports a freeze display state', () {
      final merged = mergeStreak(
        _streak(gameId: GameIds.sudoku),
        const GameStreak(
          gameId: GameIds.sudoku,
          current: 2,
          lastClearedDateId: '20261007',
          isOnFreeze: true,
        ),
      );
      expect(merged.gameId, GameIds.sudoku);
      expect(merged.isOnFreeze, isFalse);
    });

    test('compares across month and year boundaries', () {
      final merged = mergeStreak(
        _streak(current: 9, longest: 9, last: '20261231'),
        _streak(current: 1, longest: 1, last: '20270101'),
      );
      expect(merged.lastClearedDateId, '20270101');
      expect(merged.current, 1);
      expect(merged.longest, 9);
    });
  });

  group('modeKeyFor', () {
    test('matches the keys the blocs and HomeCubit build', () {
      // zip_bloc / home_cubit: 'zip_${level.id}' with
      // level.id == DailyPuzzleGenerator.dateId(...) == 'daily_<playId>'.
      expect(modeKeyFor(GameIds.zip, '20261007'), 'zip_daily_20261007');
      expect(modeKeyFor(GameIds.pathWords, '20261007'), 'path_words_20261007');
      expect(modeKeyFor(GameIds.sudoku, '20261007'), 'sudoku_20261007');
    });

    test('supports debug minute play ids', () {
      expect(modeKeyFor(GameIds.zip, '202610071530'), 'zip_daily_202610071530');
    });

    test('rejects games without daily progress', () {
      expect(
        () => modeKeyFor(GameIds.wordMatch, '20261007'),
        throwsArgumentError,
      );
    });
  });

  group('leaderboardDayIdForPlayId', () {
    test('formats a daily play id', () {
      expect(leaderboardDayIdForPlayId('20261007'), '2026-10-07');
    });

    test('uses the day of a debug minute play id', () {
      expect(leaderboardDayIdForPlayId('202610072359'), '2026-10-07');
    });

    test('rejects malformed ids', () {
      for (final bad in ['', '2026107', '2026-10-07', '2026100712', 'abc']) {
        expect(() => leaderboardDayIdForPlayId(bad), throwsArgumentError);
      }
    });
  });

  group('syncWindowPlayIds', () {
    test('daily: yesterday then today', () {
      expect(syncWindowPlayIds(DateTime(2026, 10, 7, 9), PlayPeriod.daily), [
        '20261006',
        '20261007',
      ]);
    });

    test('daily: just after midnight', () {
      expect(
        syncWindowPlayIds(DateTime(2026, 10, 7, 0, 0, 1), PlayPeriod.daily),
        ['20261006', '20261007'],
      );
    });

    test('daily: just before midnight', () {
      expect(
        syncWindowPlayIds(DateTime(2026, 10, 7, 23, 59, 59), PlayPeriod.daily),
        ['20261006', '20261007'],
      );
    });

    test('daily: month boundary', () {
      expect(syncWindowPlayIds(DateTime(2026, 11, 1, 8), PlayPeriod.daily), [
        '20261031',
        '20261101',
      ]);
    });

    test('daily: year boundary', () {
      expect(syncWindowPlayIds(DateTime(2027, 1, 1, 0, 5), PlayPeriod.daily), [
        '20261231',
        '20270101',
      ]);
    });

    test('daily: leap day', () {
      expect(syncWindowPlayIds(DateTime(2028, 3, 1, 10), PlayPeriod.daily), [
        '20280229',
        '20280301',
      ]);
    });

    test('daily: steps back one calendar day across DST changes', () {
      // US (2026-03-08) and EU (2026-03-29) spring-forward days are 23 h long;
      // fall-back days (2026-11-01 / 2026-10-25) are 25 h long. A fixed 24 h
      // step would skip or repeat a day in those zones.
      expect(syncWindowPlayIds(DateTime(2026, 3, 9, 0, 30), PlayPeriod.daily), [
        '20260308',
        '20260309',
      ]);
      expect(
        syncWindowPlayIds(DateTime(2026, 3, 30, 0, 30), PlayPeriod.daily),
        ['20260329', '20260330'],
      );
      expect(
        syncWindowPlayIds(DateTime(2026, 11, 1, 23, 30), PlayPeriod.daily),
        ['20261031', '20261101'],
      );
      expect(
        syncWindowPlayIds(DateTime(2026, 10, 25, 23, 30), PlayPeriod.daily),
        ['20261024', '20261025'],
      );
    });

    test('uses the local calendar day of a UTC instant', () {
      final now = DateTime.utc(2026, 10, 7, 12);
      expect(syncWindowPlayIds(now, PlayPeriod.daily), [
        _previousDayId(now),
        AppCalendar.dateIdCompact(now),
      ]);
    });

    test('minute: previous minute then current', () {
      expect(
        syncWindowPlayIds(DateTime(2026, 10, 7, 15, 30, 10), PlayPeriod.minute),
        ['202610071529', '202610071530'],
      );
    });

    test('minute: crosses midnight and year', () {
      expect(
        syncWindowPlayIds(DateTime(2027, 1, 1, 0, 0, 5), PlayPeriod.minute),
        ['202612312359', '202701010000'],
      );
    });

    test('deduplicates when both ends share a period id', () {
      // A sub-minute period lands in the same minute bucket.
      expect(
        syncWindowPlayIds(
          DateTime(2026, 10, 7, 15, 30, 40),
          const Duration(seconds: 10),
        ),
        ['202610071530'],
      );
    });
  });

  group('legacyClearFlags', () {
    test('zip and path words never report mistakes', () {
      expect(
        legacyClearFlags(GameIds.zip, 0),
        const ClearMeta(usedHints: false, hadMistakes: false),
      );
      expect(
        legacyClearFlags(GameIds.pathWords, 0),
        const ClearMeta(usedHints: false, hadMistakes: false),
      );
    });

    test('sudoku conservatively reports mistakes', () {
      expect(
        legacyClearFlags(GameIds.sudoku, 0),
        const ClearMeta(usedHints: false, hadMistakes: true),
      );
    });

    test('any consumed hint means usedHints', () {
      expect(legacyClearFlags(GameIds.zip, 1).usedHints, isTrue);
      expect(legacyClearFlags(GameIds.pathWords, 3).usedHints, isTrue);
      expect(
        legacyClearFlags(GameIds.sudoku, 2),
        const ClearMeta(usedHints: true, hadMistakes: true),
      );
    });
  });

  group('daySignature', () {
    test('is equal for equal synced fields', () {
      final a = _day(time: 10, points: 900, usedHints: false, hintsUsed: 1);
      final b = _day(time: 10, points: 900, usedHints: false, hintsUsed: 1);
      expect(daySignature(a), daySignature(b));
    });

    test('ignores clearedAt and ids', () {
      final a = _day(time: 10, clearedAt: DateTime.utc(2026, 10, 7));
      final b = _day(time: 10, playId: '20261006', gameId: GameIds.sudoku);
      expect(daySignature(a), daySignature(b));
    });

    test('changes when any synced field changes', () {
      final base = _day(
        time: 10,
        points: 900,
        usedHints: false,
        hadMistakes: false,
        flagsKnown: true,
        hintsUsed: 1,
      );
      final variants = [
        base.copyWith(timeSeconds: 9),
        base.copyWith(points: 901),
        base.copyWith(usedHints: true),
        base.copyWith(hadMistakes: true),
        base.copyWith(flagsKnown: false),
        base.copyWith(hintsUsed: 2),
        _day(
          points: 900,
          usedHints: false,
          hadMistakes: false,
          flagsKnown: true,
          hintsUsed: 1,
        ),
      ];
      final signatures = {
        daySignature(base),
        for (final v in variants) daySignature(v),
      };
      expect(signatures, hasLength(variants.length + 1));
    });

    test('distinguishes null from false flags', () {
      expect(
        daySignature(_day(time: 1)),
        isNot(daySignature(_day(time: 1, usedHints: false))),
      );
    });
  });

  group('streakSignature', () {
    test('is equal for equal synced fields and ignores isOnFreeze', () {
      final a = _streak(current: 2, longest: 3, last: '20261007');
      final b = a.copyWith(isOnFreeze: true);
      expect(streakSignature(a), streakSignature(b));
    });

    test('changes when any synced field changes', () {
      final base = _streak(current: 2, longest: 3, last: '20261007');
      final variants = [
        base.copyWith(current: 3),
        base.copyWith(longest: 4),
        base.copyWith(lastClearedDateId: '20261006'),
        base.copyWith(clearLastClearedDateId: true),
        base.copyWith(freezeAvailable: false),
      ];
      final signatures = {
        streakSignature(base),
        for (final v in variants) streakSignature(v),
      };
      expect(signatures, hasLength(variants.length + 1));
    });
  });
}

String _previousDayId(DateTime instant) {
  final day = AppCalendar.calendarDay(instant);
  return AppCalendar.dateIdCompact(DateTime(day.year, day.month, day.day - 1));
}
