import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/results/logic/cleared_summary_text.dart';

void main() {
  test('time, rank and clean-run chips', () {
    expect(
      clearedSummaryText(
        gameId: GameIds.zip,
        timeSeconds: 72,
        rank: 4,
        usedHints: false,
        hadMistakes: false,
      ),
      'Cleared in 1:12 · #4 today · Hint-free',
    );
  });

  test('only Sudoku claims flawless', () {
    expect(
      clearedSummaryText(
        gameId: GameIds.sudoku,
        timeSeconds: 200,
        usedHints: true,
        hadMistakes: false,
      ),
      'Cleared in 3:20 · Flawless',
    );
  });

  test('leaves out what it does not know', () {
    expect(
      clearedSummaryText(gameId: GameIds.pathWords, timeSeconds: 29),
      'Cleared in 0:29',
    );
    // Clears from before times were kept.
    expect(clearedSummaryText(gameId: GameIds.zip), 'Cleared');
  });
}
