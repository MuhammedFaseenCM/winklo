import 'package:flutter/material.dart';

import '../../../../core/config/static_assets_config.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/game_ids.dart';

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.entry,
    required this.timeLabel,
    required this.isYou,
    this.showCleanRunChips = false,
    this.gameId,
  });

  final LeaderboardEntry entry;
  final String timeLabel;
  final bool isYou;

  /// When true (daily board / mini board), show No hint / No mistakes chips.
  final bool showCleanRunChips;
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final isTop3 = rank >= 1 && rank <= 3;
    final accentBorder = switch (rank) {
      1 => const Color(0xFFFFD700).withValues(alpha: 0.8),
      2 => const Color(0xFFD4DFEB).withValues(alpha: 0.75),
      3 => const Color(0xFFE28B52).withValues(alpha: 0.75),
      _ =>
        isYou
            ? ZipColors.ember.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.08),
    };
    final accentWidth = switch (rank) {
      1 => 2.2,
      2 => 2.0,
      3 => 2.0,
      _ => isYou ? 1.5 : 1.0,
    };

    final showNoHint = showCleanRunChips && entry.usedHints == false;
    final showNoMistakes =
        showCleanRunChips &&
        gameId == GameIds.sudoku &&
        entry.hadMistakes == false;
    final chips = <Widget>[
      if (isYou)
        _chip(
          context,
          label: AppStrings.youLabel,
          foreground: ZipColors.ember,
          background: ZipColors.ember.withValues(alpha: 0.22),
          border: ZipColors.ember.withValues(alpha: 0.5),
        ),
      if (showNoHint)
        _chip(
          context,
          label: AppStrings.leaderboardNoHintChip,
          foreground: const Color(0xFF7EE0C3),
          background: const Color(0xFF5EC4A8).withValues(alpha: 0.18),
          border: const Color(0xFF7EE0C3).withValues(alpha: 0.35),
        ),
      if (showNoMistakes)
        _chip(
          context,
          label: AppStrings.leaderboardNoMistakesChip,
          foreground: const Color(0xFF9EC0FF),
          background: const Color(0xFF78AAFF).withValues(alpha: 0.16),
          border: const Color(0xFF9EC0FF).withValues(alpha: 0.35),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: isYou
            ? const LinearGradient(
                colors: [Color(0xFF38231C), Color(0xFF241712)],
              )
            : LinearGradient(
                colors: isTop3
                    ? [const Color(0xFF243248), const Color(0xFF192336)]
                    : [const Color(0xFF1F2B3E), const Color(0xFF162030)],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBorder, width: accentWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          if (rank == 1)
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 3),
            )
          else if (rank == 2)
            BoxShadow(
              color: const Color(0xFFD4DFEB).withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 2),
            )
          else if (rank == 3)
            BoxShadow(
              color: const Color(0xFFE28B52).withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          if (isYou)
            BoxShadow(
              color: ZipColors.ember.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          _leading(context),
          const SizedBox(width: 8),
          UserAvatar(
            displayName: entry.displayName,
            photoUrl: entry.photoUrl,
            avatarId: entry.avatarId,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: chips),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              timeLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isYou ? ZipColors.ember : ZipColors.onInk,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _leading(BuildContext context) {
    final rank = entry.rank;
    final medalUrl = switch (rank) {
      1 => StaticAssetsConfig.url('medals/medal_gold.png'),
      2 => StaticAssetsConfig.url('medals/medal_silver.png'),
      3 => StaticAssetsConfig.url('medals/medal_bronze.png'),
      _ => null,
    };
    if (medalUrl != null) {
      return SizedBox(
        width: 30,
        height: 30,
        child: AppImage.network(
          medalUrl,
          fit: BoxFit.contain,
          errorWidget: _rankText(context),
          placeholder: const SizedBox.shrink(),
        ),
      );
    }
    return SizedBox(width: 30, child: Center(child: _rankText(context)));
  }

  Widget _rankText(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ZipColors.paper.withValues(alpha: 0.6),
      ),
      child: Text(
        '${entry.rank}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: ZipColors.inkSoft,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
