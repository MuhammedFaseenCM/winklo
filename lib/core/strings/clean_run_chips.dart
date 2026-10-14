import 'app_strings.dart';
import '../../domain/game_ids.dart';

/// The clean-run chips the daily leaderboard shows: Hint-free, and Flawless
/// for Sudoku. Unknown flags (null) earn no chip.
List<String> cleanRunChips({
  required String gameId,
  bool? usedHints,
  bool? hadMistakes,
}) => [
  if (usedHints == false) AppStrings.leaderboardNoHintChip,
  if (gameId == GameIds.sudoku && hadMistakes == false)
    AppStrings.leaderboardNoMistakesChip,
];
