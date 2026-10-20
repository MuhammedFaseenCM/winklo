import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';

/// How many players stand on the podium; the table lists everyone else.
const int leaderboardPodiumSize = 3;

/// Seconds [entry] is behind [ahead], or null when there's nothing to show:
/// a tie, or the weekly board, which ranks by days cleared before time.
int? leaderboardGapSeconds({
  required LeaderboardEntry entry,
  required LeaderboardEntry ahead,
  required LeaderboardPeriod period,
}) {
  if (period == LeaderboardPeriod.weekly) return null;
  final gap = entry.timeSeconds - ahead.timeSeconds;
  return gap > 0 ? gap : null;
}

/// Where entry [index] starts in the board's scroll view: the podium places
/// sit at the top, and the rows start after [headExtent] (podium, badge key
/// and any column header).
double leaderboardEntryTop({
  required int index,
  required double headExtent,
  required double rowExtent,
}) {
  if (index < leaderboardPodiumSize) return 0;
  return headExtent + (index - leaderboardPodiumSize) * rowExtent;
}

/// A clean-run mark shown next to a name on the daily board.
enum LeaderboardBadge { noHints, flawless, streak }

/// The badges [entry] earns on [period]'s board for [gameId], in display
/// order. Unknown (null) fields earn nothing; only the daily board has any.
List<LeaderboardBadge> leaderboardBadgesFor(
  LeaderboardEntry entry, {
  required LeaderboardPeriod period,
  required String gameId,
}) {
  if (period != LeaderboardPeriod.daily) return const [];
  final streak = entry.currentStreak;
  return [
    if (entry.usedHints == false) LeaderboardBadge.noHints,
    if (gameId == GameIds.sudoku && entry.hadMistakes == false)
      LeaderboardBadge.flawless,
    if (streak != null && streak >= 2) LeaderboardBadge.streak,
  ];
}
