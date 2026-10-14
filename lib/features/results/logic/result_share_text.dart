import '../../../core/constants/app_urls.dart';
import '../../../core/strings/app_strings.dart';
import '../../../domain/game_ids.dart';
import 'clean_run_chips.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// A spoiler-free result to share: the game, the day, the time and the same
/// clean-run chips the leaderboard shows, then a link to the landing page.
///
/// ```
/// Winklo Zip · 9 Oct
/// ⏱ 1:12 · 🔥 5 · Hint-free
/// https://winklo.pages.dev
/// ```
String resultShareText({
  required String gameId,
  required DateTime day,
  required int timeSeconds,
  int? currentStreak,
  bool? usedHints,
  bool? hadMistakes,
}) {
  final title = switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTitle,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };
  final stats = [
    '⏱ ${AppStrings.formatPlayTime(timeSeconds)}',
    // Streak chips start at 2 days on the leaderboard too.
    if (currentStreak != null && currentStreak >= 2) '🔥 $currentStreak',
    ...cleanRunChips(
      gameId: gameId,
      usedHints: usedHints,
      hadMistakes: hadMistakes,
    ),
  ];
  return [
    'Winklo $title · ${day.day} ${_months[day.month - 1]}',
    stats.join(' · '),
    AppUrls.landing,
  ].join('\n');
}
