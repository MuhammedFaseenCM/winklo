import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/features/leaderboard/logic/mini_leaderboard_slice.dart';

LeaderboardEntry e({required int rank, String? uid, int time = 10}) {
  final id = uid ?? 'uid$rank';
  return LeaderboardEntry(
    uid: id,
    displayName: 'P$id',
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

  test('tied ranks both appear and gap uses dense values', () {
    final entries = [
      e(rank: 1, uid: 'a', time: 10),
      e(rank: 2, uid: 'b', time: 15),
      e(rank: 2, uid: 'c', time: 15),
      e(rank: 3, uid: 'd', time: 18),
      e(rank: 4, uid: 'e', time: 20),
      e(rank: 5, uid: 'f', time: 22),
      e(rank: 10, uid: 'g', time: 40),
      e(rank: 11, uid: 'h', time: 41),
      e(rank: 12, uid: 'i', time: 42),
    ];
    final items = sliceLeaderboardForMini(
      entries: entries,
      currentUid: 'h',
      above: 2,
      below: 1,
    );
    final ranks = <Object>[];
    final uids = <String>[];
    for (final item in items) {
      if (item is MiniLeaderboardGap) {
        ranks.add('gap');
      } else if (item is MiniLeaderboardEntryItem) {
        ranks.add(item.entry.rank);
        uids.add(item.entry.uid);
      }
    }
    expect(uids, ['a', 'b', 'c', 'd', 'g', 'h', 'i']);
    expect(ranks, [1, 2, 2, 3, 'gap', 10, 11, 12]);
  });

  List<int?> ranksOf(List<MiniLeaderboardItem> items) => [
    for (final item in items)
      switch (item) {
        MiniLeaderboardEntryItem(:final entry) => entry.rank,
        MiniLeaderboardGap() => null,
      },
  ];

  group('fitLeaderboardForMini', () {
    test('room for everyone shows everyone, no gap', () {
      final items = fitLeaderboardForMini(
        entries: board(6),
        currentUid: 'uid5',
        maxRows: 8,
      );
      expect(ranksOf(items), [1, 2, 3, 4, 5, 6]);
    });

    test('mid-board: podium, gap, then neighbours above first', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid14',
        maxRows: 8,
      );
      // 3 podium + you + 4 neighbours: 12, 13 above; 15, 16 below.
      expect(ranksOf(items), [1, 2, 3, null, 12, 13, 14, 15, 16]);
    });

    test('an odd slot goes above', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid14',
        maxRows: 7,
      );
      expect(ranksOf(items), [1, 2, 3, null, 12, 13, 14, 15]);
    });

    test('last place takes every slot above', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid18',
        maxRows: 6,
      );
      expect(ranksOf(items), [1, 2, 3, null, 16, 17, 18]);
    });

    test('next to the podium there is no gap', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid5',
        maxRows: 7,
      );
      expect(ranksOf(items), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('on the podium, or off the board: the top rows', () {
      expect(
        ranksOf(
          fitLeaderboardForMini(
            entries: board(18),
            currentUid: 'uid2',
            maxRows: 5,
          ),
        ),
        [1, 2, 3, 4, 5],
      );
      expect(
        ranksOf(
          fitLeaderboardForMini(
            entries: board(18),
            currentUid: 'missing',
            maxRows: 5,
          ),
        ),
        [1, 2, 3, 4, 5],
      );
    });

    test('too little room still keeps the podium and you', () {
      final items = fitLeaderboardForMini(
        entries: board(18),
        currentUid: 'uid14',
        maxRows: 2,
      );
      expect(ranksOf(items), [1, 2, 3, null, 14]);
    });

    test('a short board keeps its own size', () {
      final items = fitLeaderboardForMini(
        entries: board(2),
        currentUid: 'uid2',
        maxRows: 8,
      );
      expect(ranksOf(items), [1, 2]);
    });

    test('a tie on the podium keeps every medal', () {
      final entries = [
        e(rank: 1, uid: 'a'),
        e(rank: 2, uid: 'b'),
        e(rank: 2, uid: 'c'),
        e(rank: 3, uid: 'd'),
        for (var r = 4; r <= 12; r++) e(rank: r, uid: 'u$r'),
      ];
      final items = fitLeaderboardForMini(
        entries: entries,
        currentUid: 'u10',
        maxRows: 7,
      );
      expect(ranksOf(items), [1, 2, 2, 3, null, 9, 10, 11]);
    });

    test('an empty board has no rows', () {
      expect(
        fitLeaderboardForMini(entries: const [], currentUid: 'x', maxRows: 5),
        isEmpty,
      );
    });
  });
}
