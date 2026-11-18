import 'entities/leaderboard_entry.dart';
import 'entities/leaderboard_period.dart';

/// Orders [entries] as the server boards do and gives them dense ranks
/// (1, 2, 2, 3), for boards built on the phone (a league's members).
///
/// Daily and all-time: time ascending, then the earlier `updatedAt`. Weekly:
/// days cleared descending, then total time ascending, then `updatedAt`.
/// Levels: stars descending, then levels cleared ascending (fewer levels for
/// the same stars is better), then total time, then `updatedAt`. Entries tie
/// (share a rank) on the time, on days and total for weekly, or on stars,
/// levels and total for levels.
List<LeaderboardEntry> rankLeaderboardEntries(
  Iterable<LeaderboardEntry> entries,
  LeaderboardPeriod period,
) {
  final weekly = period == LeaderboardPeriod.weekly;
  final levels = period == LeaderboardPeriod.levels;
  final sorted = [...entries]
    ..sort((a, b) {
      if (weekly) {
        final days = (b.daysCleared ?? 0).compareTo(a.daysCleared ?? 0);
        if (days != 0) return days;
      }
      if (levels) {
        final stars = (b.stars ?? 0).compareTo(a.stars ?? 0);
        if (stars != 0) return stars;
        final cleared = (a.levelsCleared ?? 0).compareTo(b.levelsCleared ?? 0);
        if (cleared != 0) return cleared;
      }
      final time = a.timeSeconds.compareTo(b.timeSeconds);
      if (time != 0) return time;
      final updated = a.updatedAt.compareTo(b.updatedAt);
      if (updated != 0) return updated;
      return a.uid.compareTo(b.uid);
    });
  final ranked = <LeaderboardEntry>[];
  var rank = 0;
  LeaderboardEntry? previous;
  for (final entry in sorted) {
    final tied =
        previous != null &&
        previous.timeSeconds == entry.timeSeconds &&
        (!weekly || previous.daysCleared == entry.daysCleared) &&
        (!levels ||
            (previous.stars == entry.stars &&
                previous.levelsCleared == entry.levelsCleared));
    if (!tied) rank += 1;
    ranked.add(entry.withRank(rank));
    previous = entry;
  }
  return ranked;
}
