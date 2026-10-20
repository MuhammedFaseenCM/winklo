import '../../../domain/entities/leaderboard_entry.dart';
import 'board_layout.dart';

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

/// The mini board's rows when its card has room for [maxRows] entry rows.
/// It always shows the podium (everyone ranked 1 to 3, ties included) and
/// the current player; the other rows go to the player's neighbours,
/// alternating above (the players to catch) and below, starting above. A
/// player on the podium or off the board gets the top rows instead. A gap
/// marks each jump in the board.
List<MiniLeaderboardItem> fitLeaderboardForMini({
  required List<LeaderboardEntry> entries,
  required String? currentUid,
  required int maxRows,
}) {
  if (entries.isEmpty) return const [];
  var podium = 0;
  while (podium < entries.length &&
      entries[podium].rank <= leaderboardPodiumSize) {
    podium++;
  }
  final me = currentUid == null
      ? -1
      : entries.indexWhere((e) => e.uid == currentUid);
  final keep = <int>{for (var i = 0; i < podium; i++) i, if (me >= 0) me};

  final candidates = <int>[];
  if (me < podium) {
    for (var i = podium; i < entries.length; i++) {
      candidates.add(i);
    }
  } else {
    for (var d = 1; d < entries.length; d++) {
      if (me - d >= podium) candidates.add(me - d);
      if (me + d < entries.length) candidates.add(me + d);
    }
  }
  for (final i in candidates) {
    if (keep.length >= maxRows) break;
    keep.add(i);
  }

  final sorted = keep.toList()..sort();
  final items = <MiniLeaderboardItem>[];
  int? previous;
  for (final i in sorted) {
    if (previous != null && i > previous + 1) {
      items.add(const MiniLeaderboardGap());
    }
    items.add(MiniLeaderboardEntryItem(entries[i]));
    previous = i;
  }
  return items;
}
