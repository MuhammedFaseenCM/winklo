import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/features/leaderboard/logic/mini_leaderboard_slice.dart';

LeaderboardEntry e({required int rank, String uid = 'u', int time = 10}) {
  return LeaderboardEntry(
    uid: 'uid$rank',
    displayName: 'P$rank',
    timeSeconds: time,
    updatedAt: DateTime.utc(2026, 9, 24),
    rank: rank,
    photoUrl: null,
  );
}

List<LeaderboardEntry> board(int n) =>
    List.generate(n, (i) => e(rank: i + 1, uid: 'uid${i + 1}'));

void main() {
  test('missing user → top 3 only', () {
    final items = sliceLeaderboardForMini(
      entries: board(10),
      currentUid: 'missing',
    );
    expect(
      items.whereType<MiniLeaderboardEntryItem>().map((i) => i.entry.rank),
      [1, 2, 3],
    );
    expect(items.whereType<MiniLeaderboardGap>(), isEmpty);
  });

  test('user in top 3 → top 3 + up to below after 3, no gap', () {
    final items = sliceLeaderboardForMini(
      entries: board(10),
      currentUid: 'uid2',
      below: 2,
    );
    expect(items.whereType<MiniLeaderboardGap>(), isEmpty);
    expect(
      items.whereType<MiniLeaderboardEntryItem>().map((i) => i.entry.rank),
      [1, 2, 3, 4, 5],
    );
  });

  test('user at 25 → 1,2,3,gap,23,24,25,26,27', () {
    final items = sliceLeaderboardForMini(
      entries: board(30),
      currentUid: 'uid25',
    );
    final ranks = <Object>[];
    for (final item in items) {
      if (item is MiniLeaderboardGap) {
        ranks.add('gap');
      } else if (item is MiniLeaderboardEntryItem) {
        ranks.add(item.entry.rank);
      }
    }
    expect(ranks, [1, 2, 3, 'gap', 23, 24, 25, 26, 27]);
  });

  test('near end clamps below', () {
    final items = sliceLeaderboardForMini(
      entries: board(26),
      currentUid: 'uid25',
    );
    final ranks = items
        .whereType<MiniLeaderboardEntryItem>()
        .map((i) => i.entry.rank)
        .toList();
    expect(ranks, containsAll([1, 2, 3, 23, 24, 25, 26]));
    expect(ranks, isNot(contains(27)));
  });

  test('small board < 3', () {
    final items = sliceLeaderboardForMini(
      entries: board(2),
      currentUid: 'uid1',
    );
    expect(
      items.whereType<MiniLeaderboardEntryItem>().map((i) => i.entry.rank),
      [1, 2],
    );
  });

  test('empty board', () {
    expect(
      sliceLeaderboardForMini(entries: const [], currentUid: 'x'),
      isEmpty,
    );
  });
}
