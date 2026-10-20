import 'package:flutter/material.dart';

import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_layout.dart';
import 'leaderboard_badges.dart';
import 'leaderboard_podium.dart';
import 'leaderboard_table.dart';

/// The board: the podium and its badge key, then everyone else in the table
/// card, all in one scroll. The screen pins your row over it.
class LeaderboardBoardView extends StatelessWidget {
  const LeaderboardBoardView({
    super.key,
    required this.entries,
    required this.period,
    required this.gameId,
    required this.currentUid,
    required this.controller,
    required this.listKey,
    required this.headKey,
    required this.userKey,
    required this.bottomPadding,
    required this.onTapEntry,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;
  final String gameId;
  final String? currentUid;
  final ScrollController controller;

  /// On the scroll view; the screen measures your row against it.
  final Key listKey;

  /// On the podium and key; its height is where the rows start.
  final GlobalKey headKey;

  /// On your podium place or row.
  final GlobalKey userKey;

  /// Room under the last row for the pinned row and the sign-in button.
  final double bottomPadding;
  final ValueChanged<LeaderboardEntry> onTapEntry;

  @override
  Widget build(BuildContext context) {
    final rest = entries.skip(leaderboardPodiumSize).toList();
    final leader = entries.first;
    final badges = {
      for (final entry in entries)
        ...leaderboardBadgesFor(entry, period: period, gameId: gameId),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
        child: CustomScrollView(
          key: listKey,
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: KeyedSubtree(
                key: headKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LeaderboardPodium(
                      entries: entries,
                      period: period,
                      gameId: gameId,
                      currentUid: currentUid,
                      youKey: userKey,
                      onTap: onTapEntry,
                    ),
                    if (badges.isEmpty)
                      const SizedBox(height: 10)
                    else
                      LeaderboardBadgeKey(badges: badges),
                  ],
                ),
              ),
            ),
            if (rest.isNotEmpty)
              DecoratedSliver(
                decoration: leaderboardTableDecoration(),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (period == LeaderboardPeriod.weekly)
                      SliverToBoxAdapter(
                        child: LeaderboardTableHeader(period: period),
                      ),
                    SliverFixedExtentList(
                      itemExtent: leaderboardTableRowHeight,
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final entry = rest[i];
                        final isYou = entry.uid == currentUid;
                        return LeaderboardTableRow(
                          key: isYou ? userKey : null,
                          entry: entry,
                          period: period,
                          gameId: gameId,
                          isYou: isYou,
                          showDivider: i < rest.length - 1,
                          gapSeconds: leaderboardGapSeconds(
                            entry: entry,
                            ahead: leader,
                            period: period,
                          ),
                          onTap: () => onTapEntry(entry),
                        );
                      }, childCount: rest.length),
                    ),
                  ],
                ),
              ),
            SliverPadding(padding: EdgeInsets.only(bottom: bottomPadding)),
          ],
        ),
      ),
    );
  }
}
