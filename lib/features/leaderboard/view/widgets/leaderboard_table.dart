import 'package:flutter/material.dart';

import '../../../../core/config/static_assets_config.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../../../domain/game_ids.dart';

/// A board row's height; the board's list uses it as its item extent.
const double leaderboardTableRowHeight = 48;

/// The table's widest; on tablets it sits centred.
const double leaderboardTableMaxWidth = 640;

const double _rankWidth = 28;
const double _avatarRadius = 14;
const double _daysWidth = 40;
const double _timeWidth = 56;
const double _gap = 10;

const _noHintColor = Color(0xFF7EE0C3);
const _flawlessColor = Color(0xFF9EC0FF);
const _streakColor = Color(0xFFFFC27A);

/// The card the board's rows sit in, used by the shimmer too.
BoxDecoration leaderboardTableDecoration() => BoxDecoration(
  // Nearly opaque: the screen's backdrop shapes shouldn't cross the rows.
  color: ZipColors.wall.withValues(alpha: 0.92),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: ZipColors.outlineQuiet.withValues(alpha: 0.6)),
);

/// The board as a table: [period]'s column header over [child], the rows.
class LeaderboardTableCard extends StatelessWidget {
  const LeaderboardTableCard({
    super.key,
    required this.period,
    required this.child,
  });

  final LeaderboardPeriod period;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
        child: DecoratedBox(
          decoration: leaderboardTableDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LeaderboardTableHeader(period: period),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "# · Player · Time": the columns of [period]'s board.
class LeaderboardTableHeader extends StatelessWidget {
  const LeaderboardTableHeader({super.key, required this.period});

  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final timeLabel = switch (period) {
      LeaderboardPeriod.daily => AppStrings.leaderboardColumnTime,
      LeaderboardPeriod.weekly => AppStrings.leaderboardColumnTotal,
      LeaderboardPeriod.allTime => AppStrings.leaderboardColumnBest,
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ZipColors.outlineQuiet.withValues(alpha: 0.7),
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
              child: Text(
                AppStrings.leaderboardColumnDays,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: style,
              ),
            ),
          SizedBox(
            width: _timeWidth,
            child: Text(
              timeLabel,
              textAlign: TextAlign.right,
              maxLines: 1,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// One player on the board: rank, avatar, name (with clean-run icons on the
/// daily board), then the time, or days and total on the weekly board.
class LeaderboardTableRow extends StatelessWidget {
  const LeaderboardTableRow({
    super.key,
    required this.entry,
    required this.period,
    required this.gameId,
    required this.isYou,
    this.onTap,
    this.showDivider = true,
  });

  final LeaderboardEntry entry;
  final LeaderboardPeriod period;
  final String gameId;
  final bool isYou;
  final VoidCallback? onTap;

  /// The hairline under the row; off for the last row and the pinned row.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final numberStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Material(
      color: isYou
          ? ZipColors.ember.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: leaderboardTableRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              left: isYou
                  ? const BorderSide(color: ZipColors.ember, width: 3)
                  : BorderSide.none,
              bottom: showDivider
                  ? BorderSide(
                      color: ZipColors.outlineQuiet.withValues(alpha: 0.35),
                    )
                  : BorderSide.none,
            ),
          ),
          child: Row(
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
              ),
              const SizedBox(width: _gap),
              Expanded(child: _name(context)),
              if (period == LeaderboardPeriod.weekly)
                SizedBox(
                  width: _daysWidth,
                  child: Text(
                    '${entry.daysCleared ?? 0}',
                    textAlign: TextAlign.center,
                    style: numberStyle?.copyWith(color: ZipColors.teal),
                  ),
                ),
              SizedBox(
                width: _timeWidth,
                child: Text(
                  AppStrings.formatPlayTime(entry.timeSeconds),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: numberStyle?.copyWith(
                    color: isYou ? ZipColors.ember : ZipColors.onInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rank(BuildContext context) {
    final text = Text(
      '${entry.rank}',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: ZipColors.inkSoft,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final medal = switch (entry.rank) {
      1 => 'medals/medal_gold.png',
      2 => 'medals/medal_silver.png',
      3 => 'medals/medal_bronze.png',
      _ => null,
    };
    if (medal == null) return text;
    return Semantics(
      label: '${entry.rank}',
      excludeSemantics: true,
      child: SizedBox(
        width: 24,
        height: 24,
        child: AppImage.network(
          StaticAssetsConfig.url(medal),
          fit: BoxFit.contain,
          errorWidget: Center(child: text),
          placeholder: Center(child: text),
        ),
      ),
    );
  }

  Widget _name(BuildContext context) {
    final daily = period == LeaderboardPeriod.daily;
    final streak = entry.currentStreak;
    return Row(
      children: [
        Flexible(
          child: Text(
            entry.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (daily && entry.usedHints == false) ...[
          const SizedBox(width: 6),
          const _NoHintIcon(),
        ],
        if (daily &&
            gameId == GameIds.sudoku &&
            entry.hadMistakes == false) ...[
          const SizedBox(width: 4),
          Semantics(
            label: AppStrings.leaderboardNoMistakesChip,
            excludeSemantics: true,
            child: const Icon(
              Icons.verified_rounded,
              size: 14,
              color: _flawlessColor,
            ),
          ),
        ],
        if (daily && streak != null && streak >= 2) ...[
          const SizedBox(width: 4),
          Semantics(
            label: AppStrings.streakLabel(streak),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: _streakColor,
                ),
                Text(
                  '$streak',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _streakColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A struck-through bulb: solved without a hint.
class _NoHintIcon extends StatelessWidget {
  const _NoHintIcon();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.leaderboardNoHintChip,
      excludeSemantics: true,
      child: const SizedBox(
        width: 14,
        height: 14,
        child: CustomPaint(
          foregroundPainter: _SlashPainter(_noHintColor),
          child: Icon(
            Icons.lightbulb_outline_rounded,
            size: 14,
            color: _noHintColor,
          ),
        ),
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  const _SlashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.12),
      Offset(size.width * 0.88, size.height * 0.88),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SlashPainter oldDelegate) => oldDelegate.color != color;
}
