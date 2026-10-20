import '../../../domain/game_ids.dart';

/// One stat tile under a daily result's time.
sealed class ResultTile {
  const ResultTile();
}

/// "6-day streak", with the longest streak when it's longer.
final class StreakTile extends ResultTile {
  const StreakTile({required this.days, this.longest});

  final int days;
  final int? longest;
}

final class PersonalBestTile extends ResultTile {
  const PersonalBestTile();
}

/// The seconds hints added to the time, so it doesn't read as a slow solve.
final class HintTimeTile extends ResultTile {
  const HintTimeTile(this.seconds);

  final int seconds;
}

final class HintFreeTile extends ResultTile {
  const HintFreeTile();
}

/// Sudoku with no hints and no mistakes.
final class FlawlessTile extends ResultTile {
  const FlawlessTile();
}

/// Path Words' bonus words, found beyond the list.
final class BonusWordsTile extends ResultTile {
  const BonusWordsTile(this.count);

  final int count;
}

/// The most tiles a result shows.
const int resultTilesMax = 3;

/// The tiles for a daily clear, in order: the streak, a new best, one
/// clean-run tile, then Path Words' bonus words, keeping the first
/// [resultTilesMax]. Only what's true shows; unknown (null) facts show
/// nothing. Hint time comes before the bonus words, so a time that hints
/// pushed up is always explained.
List<ResultTile> resultTilesFor({
  required String gameId,
  required bool improved,
  int? currentStreak,
  int? longestStreak,
  bool? usedHints,
  bool? hadMistakes,
  int hintPenaltySeconds = 0,
  int bonusWords = 0,
}) {
  final streak = currentStreak ?? 0;
  final longest = longestStreak;
  final tiles = <ResultTile>[
    if (streak > 0)
      StreakTile(
        days: streak,
        longest: longest != null && longest > streak ? longest : null,
      ),
    if (improved) const PersonalBestTile(),
    if (hintPenaltySeconds > 0)
      HintTimeTile(hintPenaltySeconds)
    else if (gameId == GameIds.sudoku &&
        usedHints == false &&
        hadMistakes == false)
      const FlawlessTile()
    else if (usedHints == false)
      const HintFreeTile(),
    if (gameId == GameIds.pathWords && bonusWords > 0)
      BonusWordsTile(bonusWords),
  ];
  return tiles.take(resultTilesMax).toList();
}
