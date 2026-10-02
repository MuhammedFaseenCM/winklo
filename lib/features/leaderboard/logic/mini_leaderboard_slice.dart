import '../../../domain/entities/leaderboard_entry.dart';

sealed class MiniLeaderboardItem {
  const MiniLeaderboardItem();
}

final class MiniLeaderboardEntryItem extends MiniLeaderboardItem {
  const MiniLeaderboardEntryItem(this.entry);
  final LeaderboardEntry entry;
}

final class MiniLeaderboardGap extends MiniLeaderboardItem {
  const MiniLeaderboardGap();
}

List<MiniLeaderboardItem> sliceLeaderboardForMini({
  required List<LeaderboardEntry> entries,
  required String? currentUid,
  int above = 2,
  int below = 2,
}) {
  if (entries.isEmpty) return const [];

  LeaderboardEntry? me;
  if (currentUid != null) {
    for (final e in entries) {
      if (e.uid == currentUid) {
        me = e;
        break;
      }
    }
  }

  final selected = <LeaderboardEntry>[];
  for (final e in entries) {
    if (e.rank <= 3) {
      selected.add(e);
      continue;
    }
    if (me == null) continue;
    if (me.rank <= 3) {
      if (e.rank > 3 && e.rank <= 3 + below) selected.add(e);
    } else {
      final lo = me.rank - above;
      final hi = me.rank + below;
      if (e.rank >= lo && e.rank <= hi) selected.add(e);
    }
  }

  final items = <MiniLeaderboardItem>[];
  int? prevRank;
  for (final e in selected) {
    if (prevRank != null && e.rank > prevRank + 1) {
      items.add(const MiniLeaderboardGap());
    }
    items.add(MiniLeaderboardEntryItem(e));
    prevRank = e.rank;
  }
  return items;
}
