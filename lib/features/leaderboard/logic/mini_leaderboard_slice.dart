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

  final byRank = <int, LeaderboardEntry>{for (final e in entries) e.rank: e};
  final ranks = byRank.keys.toList()..sort();

  LeaderboardEntry? me;
  if (currentUid != null) {
    for (final e in entries) {
      if (e.uid == currentUid) {
        me = e;
        break;
      }
    }
  }

  final selected = <int>{};
  for (final r in ranks) {
    if (r <= 3) selected.add(r);
  }

  if (me == null) {
    return [
      for (final r in selected.toList()..sort())
        MiniLeaderboardEntryItem(byRank[r]!),
    ];
  }

  if (me.rank <= 3) {
    for (final r in ranks) {
      if (r > 3 && r <= 3 + below) selected.add(r);
    }
  } else {
    final lo = me.rank - above;
    final hi = me.rank + below;
    for (final r in ranks) {
      if (r >= lo && r <= hi) selected.add(r);
    }
  }

  final ordered = selected.toList()..sort();
  final items = <MiniLeaderboardItem>[];
  int? prev;
  for (final r in ordered) {
    if (prev != null && r > prev + 1) {
      items.add(const MiniLeaderboardGap());
    }
    items.add(MiniLeaderboardEntryItem(byRank[r]!));
    prev = r;
  }
  return items;
}
