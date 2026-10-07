import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/game_day_record.dart';

void main() {
  final clearedAt = DateTime.utc(2026, 10, 7, 9);
  GameDayRecord full() => GameDayRecord(
    gameId: 'zip',
    playId: '20261007',
    timeSeconds: 12,
    points: 940,
    usedHints: false,
    hadMistakes: false,
    flagsKnown: true,
    hintsUsed: 1,
    clearedAt: clearedAt,
  );

  test('cleared iff timeSeconds is present', () {
    expect(full().cleared, isTrue);
    expect(
      const GameDayRecord(gameId: 'zip', playId: '20261007').cleared,
      isFalse,
    );
    expect(
      const GameDayRecord(gameId: 'zip', playId: '20261007', points: 5).cleared,
      isFalse,
    );
  });

  test('defaults hintsUsed to 0 and optional fields to null', () {
    const r = GameDayRecord(gameId: 'sudoku', playId: '20261007');
    expect(r.hintsUsed, 0);
    expect(r.timeSeconds, isNull);
    expect(r.points, isNull);
    expect(r.usedHints, isNull);
    expect(r.hadMistakes, isNull);
    expect(r.flagsKnown, isNull);
    expect(r.clearedAt, isNull);
  });

  test('value equality covers every field', () {
    expect(full(), full());
    expect(full().hashCode, full().hashCode);
    final variants = [
      full().copyWith(gameId: 'sudoku'),
      full().copyWith(playId: '20261006'),
      full().copyWith(timeSeconds: 13),
      full().copyWith(points: 941),
      full().copyWith(usedHints: true),
      full().copyWith(hadMistakes: true),
      full().copyWith(flagsKnown: false),
      full().copyWith(hintsUsed: 2),
      full().copyWith(clearedAt: clearedAt.add(const Duration(seconds: 1))),
    ];
    for (final v in variants) {
      expect(v, isNot(full()), reason: '$v');
    }
  });

  test('copyWith keeps unspecified fields', () {
    final r = full().copyWith(hintsUsed: 3);
    expect(r.hintsUsed, 3);
    expect(r.timeSeconds, 12);
    expect(r.clearedAt, clearedAt);
    expect(r.copyWith(), full().copyWith(hintsUsed: 3));
  });
}
