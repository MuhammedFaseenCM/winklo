import '../../strings/app_strings.dart';
import '../../strings/clean_run_chips.dart';

/// "Cleared in 1:12 · #4 today · Hint-free" for a daily reopened after its
/// clear.
String clearedSummaryText({
  required String gameId,
  int? timeSeconds,
  int? rank,
  bool? usedHints,
  bool? hadMistakes,
}) => [
  timeSeconds == null
      ? AppStrings.cleared
      : AppStrings.clearedIn(AppStrings.formatPlayTime(timeSeconds)),
  if (rank != null) AppStrings.rankToday(rank),
  ...cleanRunChips(
    gameId: gameId,
    usedHints: usedHints,
    hadMistakes: hadMistakes,
  ),
].join(' · ');
