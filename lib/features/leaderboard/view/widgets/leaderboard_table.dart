import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_layout.dart';
import 'leaderboard_badges.dart';
import 'medal_coin.dart';

/// A board row's height; the board's list uses it as its item extent.
const double leaderboardTableRowHeight = 52;

/// The weekly board's column header above the rows.
const double leaderboardTableHeaderHeight = 30;

/// The table's widest; on tablets it sits centred.
const double leaderboardTableMaxWidth = 640;

const double _rankWidth = 28;
const double _avatarRadius = 14;
const double _daysWidth = 40;
const double _timeWidth = 56;
const double _gap = 10;
const double _youBarWidth = 3;

/// The card the board's rows sit in, used by the shimmer too.
BoxDecoration leaderboardTableDecoration() => BoxDecoration(
  // Nearly opaque: the screen's backdrop shapes shouldn't cross the rows.
  color: ZipColors.wall.withValues(alpha: 0.92),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: ZipColors.outlineQuiet.withValues(alpha: 0.6)),
);

/// "# · Player · Time": the columns of [period]'s board.
class LeaderboardTableHeader extends StatelessWidget {
  const LeaderboardTableHeader({super.key, required this.period});

  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft.withValues(alpha: 0.9),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final timeLabel = switch (period) {
      LeaderboardPeriod.daily => AppStrings.leaderboardColumnTime,
      LeaderboardPeriod.weekly => AppStrings.leaderboardColumnTotal,
      LeaderboardPeriod.allTime => AppStrings.leaderboardColumnBest,
    };
    return Container(
      height: leaderboardTableHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: ZipColors.outlineQuiet.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _rankWidth,
            child: Text('#', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: _gap + _avatarRadius * 2 + _gap),
          Expanded(
            child: Text(
              AppStrings.leaderboardColumnPlayer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (period == LeaderboardPeriod.weekly)
            SizedBox(
              width: _daysWidth,
              child: _FitCell(
                alignment: Alignment.centerRight,
                child: Text(
                  AppStrings.leaderboardColumnDays,
                  maxLines: 1,
                  style: style,
                ),
              ),
            ),
          SizedBox(
            width: _timeWidth,
            child: _FitCell(
              alignment: Alignment.centerRight,
              child: Text(timeLabel, maxLines: 1, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// One player below the podium: rank, avatar, name (with clean-run icons on
/// the daily board), then the time and its gap to #1, or days and total on
/// the weekly board.
class LeaderboardTableRow extends StatelessWidget {
  const LeaderboardTableRow({
    super.key,
    required this.entry,
    required this.period,
    required this.gameId,
    required this.isYou,
    this.onTap,
    this.showDivider = true,
    this.gapSeconds,
    this.subtitle,
    this.showMedals = false,
  });

  final LeaderboardEntry entry;
  final LeaderboardPeriod period;
  final String gameId;
  final bool isYou;
  final VoidCallback? onTap;

  /// The hairline under the row; off for the last row and the pinned row.
  final bool showDivider;

  /// Seconds behind #1, shown under the time.
  final int? gapSeconds;

  /// A line under the name (the pinned row's "behind #N").
  final String? subtitle;

  /// A medal instead of the number for ranks 1 to 3: the Results mini
  /// board, which has no podium above its rows.
  final bool showMedals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final numberStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: -0.2,
    );
    final row = Row(
      children: [
        SizedBox(
          width: _rankWidth,
          child: Center(child: _rank(context)),
        ),
        const SizedBox(width: _gap),
        UserAvatar(
          displayName: entry.displayName,
          photoUrl: entry.photoUrl,
          avatarId: entry.avatarId,
          radius: _avatarRadius,
          tintSeed: entry.uid,
        ),
        const SizedBox(width: _gap),
        Expanded(child: _name(context)),
        if (period == LeaderboardPeriod.weekly)
          SizedBox(
            width: _daysWidth,
            child: _FitCell(
              alignment: Alignment.centerRight,
              child: Text(
                '${entry.daysCleared ?? 0}',
                style: numberStyle?.copyWith(
                  color: ZipColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        SizedBox(
          width: _timeWidth,
          child: _FitCell(
            alignment: Alignment.centerRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppStrings.formatPlayTime(entry.timeSeconds),
                  maxLines: 1,
                  style: numberStyle?.copyWith(
                    color: isYou
                        ? ZipColors.ember
                        : ZipColors.onInk.withValues(alpha: 0.95),
                  ),
                ),
                if (gapSeconds case final gap?)
                  Text(
                    '+${AppStrings.formatPlayTime(gap)}',
                    maxLines: 1,
                    style: textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft.withValues(alpha: 0.75),
                      fontSize: 10.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return Material(
      color: isYou
          ? ZipColors.ember.withValues(alpha: 0.14)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: ZipColors.ember.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          // The board's rows have a fixed extent; the pinned row's sub-line
          // may need more at big text sizes.
          height: subtitle == null ? leaderboardTableRowHeight : null,
          constraints: subtitle == null
              ? null
              : const BoxConstraints(minHeight: leaderboardTableRowHeight),
          padding: EdgeInsets.only(
            left: isYou ? 12 - _youBarWidth : 12,
            right: 12,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: isYou
                  ? const BorderSide(
                      color: ZipColors.ember,
                      width: _youBarWidth,
                    )
                  : BorderSide.none,
              bottom: showDivider
                  ? BorderSide(
                      color: ZipColors.outlineQuiet.withValues(alpha: 0.22),
                    )
                  : BorderSide.none,
            ),
          ),
          child: row,
        ),
      ),
    );
  }

  Widget _rank(BuildContext context) {
    final rank = entry.rank;
    if (showMedals && rank >= 1 && rank <= leaderboardPodiumSize) {
      return MedalCoin(rank: rank, size: 22);
    }
    return Text(
      '$rank',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: isYou ? ZipColors.ember : ZipColors.inkSoft,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _name(BuildContext context) {
    final theme = Theme.of(context);
    final badges = leaderboardBadgesFor(entry, period: period, gameId: gameId);
    final nameRow = Row(
      children: [
        Flexible(
          child: Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: ZipColors.onInk,
              fontWeight: isYou ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        if (isYou) ...[const SizedBox(width: 6), const LeaderboardYouPill()],
        if (badges.isNotEmpty) ...[
          const SizedBox(width: 6),
          LeaderboardBadgeIcons(entry: entry, badges: badges),
        ],
      ],
    );
    final line = subtitle;
    if (line == null) return nameRow;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nameRow,
        Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0xFFFFB18A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Compact "You" marker next to the player's name.
class LeaderboardYouPill extends StatelessWidget {
  const LeaderboardYouPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ZipColors.ember.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ZipColors.ember.withValues(alpha: 0.45)),
      ),
      child: Text(
        AppStrings.youLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ZipColors.ember,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}

/// A fixed-width column's content: shrinks to fit at large text sizes
/// instead of being cut ("140:32" at 1.6× is wider than the column).
class _FitCell extends StatelessWidget {
  const _FitCell({required this.alignment, required this.child});

  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: child);
  }
}
