import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/results/logic/result_share_text.dart';

void main() {
  final day = DateTime(2026, 10, 9);

  test('a hint-free Zip with a streak', () {
    expect(
      resultShareText(
        gameId: GameIds.zip,
        day: day,
        timeSeconds: 72,
        currentStreak: 5,
        usedHints: false,
        hadMistakes: false,
      ),
      'Winklo Zip · 9 Oct\n'
      '⏱ 1:12 · 🔥 5 · Hint-free\n'
      'https://winklo.pages.dev',
    );
  });

  test('leaves out a one-day streak and hint use', () {
    expect(
      resultShareText(
        gameId: GameIds.pathWords,
        day: day,
        timeSeconds: 205,
        currentStreak: 1,
        usedHints: true,
      ),
      'Winklo Path Words · 9 Oct\n'
      '⏱ 3:25\n'
      'https://winklo.pages.dev',
    );
  });

  test('a Sudoku without mistakes is flawless', () {
    expect(
      resultShareText(
        gameId: GameIds.sudoku,
        day: DateTime(2026, 12, 31),
        timeSeconds: 59,
        usedHints: false,
        hadMistakes: false,
      ),
      'Winklo Sudoku · 31 Dec\n'
      '⏱ 0:59 · Hint-free · Flawless\n'
      'https://winklo.pages.dev',
    );
  });

  test('only Sudoku claims flawless', () {
    final text = resultShareText(
      gameId: GameIds.zip,
      day: day,
      timeSeconds: 59,
      usedHints: true,
      hadMistakes: false,
    );
    expect(text, isNot(contains('Flawless')));
  });

  test('says nothing about the board, so it never spoils the puzzle', () {
    final text = resultShareText(
      gameId: GameIds.zip,
      day: day,
      timeSeconds: 72,
    );
    expect(text.split('\n'), hasLength(3));
  });
}
