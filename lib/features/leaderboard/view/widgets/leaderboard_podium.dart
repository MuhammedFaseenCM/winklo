import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_layout.dart';
import 'leaderboard_badges.dart';
import 'leaderboard_table.dart';
import 'medal_coin.dart';

/// The top of the board on a podium: second, first and third from the left.
/// A missing place keeps its column, so first always stands in the middle.
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.entries,
    required this.period,
    required this.gameId,
    required this.currentUid,
    required this.onTap,
    this.youKey,
  });

  /// The board's first entries; only the first [leaderboardPodiumSize] show.
  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;
  final String gameId;
  final String? currentUid;
  final ValueChanged<LeaderboardEntry> onTap;

  /// Put on your place, so the screen can tell when it's on screen.
  final Key? youKey;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    Widget place(int index, int flex) {
      final entry = index < entries.length ? entries[index] : null;
      if (entry == null) return Expanded(flex: flex, child: const SizedBox());
      final isYou = entry.uid == currentUid;
      final child = _PodiumPlace(
        entry: entry,
        place: index + 1,
        period: period,
        gameId: gameId,
        isYou: isYou,
        onTap: () => onTap(entry),
      );
      return Expanded(
        flex: flex,
        child: isYou && youKey != null
            ? KeyedSubtree(key: youKey, child: child)
            : child,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(4, layout.space(6), 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          place(1, 10),
          const SizedBox(width: 8),
          place(0, 11),
          const SizedBox(width: 8),
          place(2, 10),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.place,
    required this.period,
    required this.gameId,
    required this.isYou,
    required this.onTap,
  });

  final LeaderboardEntry entry;

  /// 1, 2 or 3: sets the step height (the medal follows the rank).
  final int place;
  final LeaderboardPeriod period;
  final String gameId;
  final bool isYou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final textTheme = Theme.of(context).textTheme;
    final first = place == 1;
    // By rank, so a tie for first is two golds; the step height is by place.
    final medal = podiumColor(entry.rank) ?? podiumColor(place)!;
    final badges = leaderboardBadgesFor(entry, period: period, gameId: gameId);
    final time = AppStrings.formatPlayTime(entry.timeSeconds);
    final days = period == LeaderboardPeriod.weekly
        ? AppStrings.leaderboardDaysShort(entry.daysCleared ?? 0)
        : null;
    final label = [
      AppStrings.leaderboardPodiumSemantics(
        entry.rank,
        entry.displayName,
        time,
      ),
      ?days,
      if (isYou) AppStrings.youLabel,
      for (final badge in badges) leaderboardBadgeSemantics(badge, entry),
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      // The InkWell's own tap is excluded with the rest, so give it here.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (first)
              AppIcon(
                AppIcons.crown,
                size: layout.space(20),
                color: leaderboardGold,
              ),
            SizedBox(height: layout.space(3)),
            // Medal ring, a thin ink gap, then the avatar on an opaque
            // backing (a tinted initials avatar is see-through).
            Container(
              padding: EdgeInsets.all(first ? 2.5 : 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: medal,
                boxShadow: first
                    ? [
                        BoxShadow(
                          color: leaderboardGold.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZipColors.ink,
                ),
                child: UserAvatar(
                  displayName: entry.displayName,
                  photoUrl: entry.photoUrl,
                  avatarId: entry.avatarId,
                  radius: layout.space(first ? 25 : 20),
                  tintSeed: entry.uid,
                ),
              ),
            ),
            SizedBox(height: layout.space(6)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: isYou ? ZipColors.ember : ZipColors.onInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  LeaderboardBadgeIcons(
                    entry: entry,
                    badges: badges,
                    size: 13,
                    showStreakCount: first,
                  ),
                ],
              ],
            ),
            if (isYou)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: LeaderboardYouPill(),
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                maxLines: 1,
                style: textTheme.titleSmall?.copyWith(
                  color: first
                      ? leaderboardGold
                      : ZipColors.onInk.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: first ? 16 : 14,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (days != null)
              Text(
                days,
                maxLines: 1,
                style: textTheme.labelSmall?.copyWith(color: ZipColors.inkSoft),
              ),
            SizedBox(height: layout.space(6)),
            // The step: slate like the table card, with a medal-coloured lip.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: Container(
                height: layout.space(switch (place) {
                  1 => 60,
                  2 => 44,
                  _ => 32,
                }),
                width: double.infinity,
                alignment: Alignment.topCenter,
                padding: EdgeInsets.only(top: layout.space(first ? 9 : 7)),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: medal.withValues(alpha: 0.85),
                      width: 3,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.alphaBlend(
                        medal.withValues(alpha: 0.1),
                        ZipColors.paper,
                      ),
                      ZipColors.wall.withValues(alpha: 0.92),
                    ],
                  ),
                ),
                child: MedalCoin(rank: entry.rank, size: layout.space(22)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
