import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/results/logic/result_tiles.dart';

void main() {
  test('streak, best and hint time, in that order', () {
    final tiles = resultTilesFor(
      gameId: GameIds.zip,
      improved: true,
      currentStreak: 6,
      longestStreak: 11,
      usedHints: true,
      hintPenaltySeconds: 20,
    );
    expect(tiles, [
      isA<StreakTile>()
          .having((t) => t.days, 'days', 6)
          .having((t) => t.longest, 'longest', 11),
      isA<PersonalBestTile>(),
      isA<HintTimeTile>().having((t) => t.seconds, 'seconds', 20),
    ]);
  });

  test('the longest streak shows only when it beats the current one', () {
    final tiles = resultTilesFor(
      gameId: GameIds.zip,
      improved: false,
      currentStreak: 11,
      longestStreak: 11,
    );
    expect(
      tiles.single,
      isA<StreakTile>().having((t) => t.longest, 'longest', isNull),
    );
  });

  test('no hints is hint-free; Sudoku without mistakes too is flawless', () {
    expect(
      resultTilesFor(gameId: GameIds.zip, improved: false, usedHints: false),
      [isA<HintFreeTile>()],
    );
    expect(
      resultTilesFor(
        gameId: GameIds.sudoku,
        improved: false,
        usedHints: false,
        hadMistakes: false,
      ),
      [isA<FlawlessTile>()],
    );
    expect(
      resultTilesFor(
        gameId: GameIds.sudoku,
        improved: false,
        usedHints: false,
        hadMistakes: true,
      ),
      [isA<HintFreeTile>()],
    );
  });

  test('unknown hint use earns no clean-run tile', () {
    expect(resultTilesFor(gameId: GameIds.zip, improved: false), isEmpty);
  });

  test('Path Words bonus words fill a free slot', () {
    expect(
      resultTilesFor(
        gameId: GameIds.pathWords,
        improved: false,
        currentStreak: 6,
        usedHints: false,
        bonusWords: 2,
      ),
      [
        isA<StreakTile>(),
        isA<HintFreeTile>(),
        isA<BonusWordsTile>().having((t) => t.count, 'count', 2),
      ],
    );
  });

  test('at most three, and hint time is never the one dropped', () {
    final tiles = resultTilesFor(
      gameId: GameIds.pathWords,
      improved: true,
      currentStreak: 3,
      usedHints: true,
      hintPenaltySeconds: 10,
      bonusWords: 4,
    );
    expect(tiles, hasLength(resultTilesMax));
    expect(tiles.last, isA<HintTimeTile>());
    expect(tiles.whereType<BonusWordsTile>(), isEmpty);
  });

  test('bonus words only count for Path Words', () {
    expect(
      resultTilesFor(gameId: GameIds.zip, improved: false, bonusWords: 3),
      isEmpty,
    );
  });
}
