import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/domain/achievements/achievement_rules.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/game_ids.dart';

GameDayRecord _clear(
  String gameId,
  String playId, {
  int time = 90,
  bool usedHints = false,
  bool hadMistakes = false,
  bool flagsKnown = true,
  int hintsUsed = 0,
}) => GameDayRecord(
  gameId: gameId,
  playId: playId,
  timeSeconds: time,
  usedHints: usedHints,
  hadMistakes: hadMistakes,
  flagsKnown: flagsKnown,
  hintsUsed: hintsUsed,
);

/// Consecutive `YYYYMMDD` ids for [count] days from [start].
List<String> _days(DateTime start, int count) => [
  for (var i = 0; i < count; i++)
    () {
      final d = DateTime(start.year, start.month, start.day + i);
      return '${d.year}${d.month.toString().padLeft(2, '0')}'
          '${d.day.toString().padLeft(2, '0')}';
    }(),
];

Set<String> _unlocked(
  List<GameDayRecord> days, {
  Map<String, int> longest = const {},
}) => unlockedAchievementIds(
  AchievementInput.fromDays(days, longestStreakByGame: longest),
);

void main() {
  test('the catalog has 16 unique ids', () {
    final ids = Achievements.all.map((a) => a.id).toList();
    expect(ids, hasLength(16));
    expect(ids.toSet(), hasLength(16));
    expect(Achievements.byId('perfect_day')?.kind, AchievementKind.perfectDay);
    expect(Achievements.byId('nope'), isNull);
  });

  test('nothing is unlocked with no clears', () {
    expect(_unlocked(const []), isEmpty);
  });

  test('uncleared days unlock nothing', () {
    expect(
      _unlocked(const [
        GameDayRecord(gameId: GameIds.zip, playId: '20261001', hintsUsed: 1),
      ]),
      isEmpty,
    );
  });

  test('first clear per game', () {
    expect(_unlocked([_clear(GameIds.pathWords, '20261001')]), {
      'first_clear_path_words',
    });
  });

  group('streaks', () {
    test('7-day streak from the stored longest', () {
      expect(
        _unlocked(
          [_clear(GameIds.sudoku, '20261001')],
          longest: {GameIds.sudoku: 7},
        ),
        containsAll(['streak_7_sudoku']),
      );
      expect(
        _unlocked(
          [_clear(GameIds.sudoku, '20261001')],
          longest: {GameIds.sudoku: 6},
        ),
        isNot(contains('streak_7_sudoku')),
      );
    });

    test('30-day streak from a run of cleared days across a month end', () {
      final days = [
        for (final id in _days(DateTime(2026, 9, 20), 30))
          _clear(GameIds.zip, id),
      ];
      final unlocked = _unlocked(days);
      expect(unlocked, containsAll(['streak_7_zip', 'streak_30_zip']));
      expect(unlocked, isNot(contains('streak_100_zip')));
      expect(unlocked, isNot(contains('streak_7_sudoku')));
    });

    test('100-day streak needs 100', () {
      expect(
        _unlocked(
          [_clear(GameIds.zip, '20261001')],
          longest: {GameIds.zip: 99},
        ),
        isNot(contains('streak_100_zip')),
      );
      expect(
        _unlocked(
          [_clear(GameIds.zip, '20261001')],
          longest: {GameIds.zip: 100},
        ),
        contains('streak_100_zip'),
      );
    });

    test('a gap breaks the day run', () {
      final ids = _days(DateTime(2026, 10, 1), 8)..removeAt(4);
      final unlocked = _unlocked([
        for (final id in ids) _clear(GameIds.zip, id),
      ]);
      expect(unlocked, isNot(contains('streak_7_zip')));
    });
  });

  group('Zip under a minute', () {
    test('needs a Zip under 60 s', () {
      expect(
        _unlocked([_clear(GameIds.zip, '20261001', time: 59)]),
        contains('zip_under_minute'),
      );
      expect(
        _unlocked([_clear(GameIds.zip, '20261001', time: 60)]),
        isNot(contains('zip_under_minute')),
      );
    });

    test('another game under a minute does not count', () {
      expect(
        _unlocked([_clear(GameIds.pathWords, '20261001', time: 20)]),
        isNot(contains('zip_under_minute')),
      );
    });
  });

  group('hint-free week', () {
    test('needs 7 days in a row of hint-free clears in one game', () {
      final days = [
        for (final id in _days(DateTime(2026, 9, 27), 7))
          _clear(GameIds.pathWords, id),
      ];
      expect(_unlocked(days), contains('hint_free_week'));
      expect(_unlocked(days.sublist(1)), isNot(contains('hint_free_week')));
    });

    test('hint-free days split across games do not count', () {
      final ids = _days(DateTime(2026, 10, 1), 7);
      final days = [
        for (var i = 0; i < ids.length; i++)
          _clear(i.isEven ? GameIds.zip : GameIds.sudoku, ids[i]),
      ];
      expect(_unlocked(days), isNot(contains('hint_free_week')));
    });

    test('a hinted day breaks the run', () {
      final ids = _days(DateTime(2026, 10, 1), 7);
      final days = [
        for (var i = 0; i < ids.length; i++)
          _clear(GameIds.zip, ids[i], usedHints: i == 3),
      ];
      expect(_unlocked(days), isNot(contains('hint_free_week')));
    });

    test('legacy clears count when no hint was spent that day', () {
      final days = [
        for (final id in _days(DateTime(2026, 10, 1), 7))
          GameDayRecord(gameId: GameIds.zip, playId: id, timeSeconds: 80),
      ];
      expect(_unlocked(days), contains('hint_free_week'));
    });
  });

  group('ten flawless Sudokus', () {
    test('needs ten clears with no hints and no mistakes', () {
      final ids = _days(DateTime(2026, 9, 1), 12);
      final days = [
        for (var i = 0; i < ids.length; i++)
          _clear(GameIds.sudoku, ids[i], hadMistakes: i < 2),
      ];
      expect(_unlocked(days), contains('flawless_sudoku_10'));
      expect(
        _unlocked(days.sublist(0, 11)),
        isNot(contains('flawless_sudoku_10')),
      );
    });

    test('legacy Sudoku clears are not flawless', () {
      final days = [
        for (final id in _days(DateTime(2026, 9, 1), 10))
          _clear(
            GameIds.sudoku,
            id,
            hadMistakes: true, // the conservative legacy guess
            flagsKnown: false,
          ),
      ];
      expect(_unlocked(days), isNot(contains('flawless_sudoku_10')));
    });

    test('flawless Zips do not count', () {
      final days = [
        for (final id in _days(DateTime(2026, 9, 1), 10))
          _clear(GameIds.zip, id),
      ];
      expect(_unlocked(days), isNot(contains('flawless_sudoku_10')));
    });
  });

  group('perfect day', () {
    test('needs all three games on one date', () {
      expect(
        _unlocked([
          _clear(GameIds.zip, '20261001'),
          _clear(GameIds.pathWords, '20261001'),
          _clear(GameIds.sudoku, '20261001'),
        ]),
        contains('perfect_day'),
      );
    });

    test('the same day in two games is not a perfect day', () {
      expect(
        _unlocked([
          _clear(GameIds.zip, '20261001'),
          _clear(GameIds.pathWords, '20261001'),
          _clear(GameIds.sudoku, '20261002'),
        ]),
        isNot(contains('perfect_day')),
      );
    });

    test('debug periods count by their date', () {
      expect(
        _unlocked([
          _clear(GameIds.zip, '202610010900'),
          _clear(GameIds.pathWords, '202610011200'),
          _clear(GameIds.sudoku, '202610012300'),
        ]),
        contains('perfect_day'),
      );
    });
  });

  test('records of other games are ignored', () {
    expect(_unlocked([_clear(GameIds.wordMatch, '20261001')]), isEmpty);
  });

  group('newlyUnlocked', () {
    test('keeps catalog order and skips seen ids', () {
      final fresh = newlyUnlocked(
        unlocked: {'streak_7_zip', 'perfect_day', 'first_clear_zip'},
        seen: {'first_clear_zip'},
      );
      expect(fresh.map((a) => a.id), ['perfect_day', 'streak_7_zip']);
    });

    test('ignores unknown ids', () {
      expect(newlyUnlocked(unlocked: {'retired'}, seen: const {}), isEmpty);
    });
  });
}
