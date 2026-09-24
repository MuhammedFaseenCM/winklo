import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.entry,
    required this.timeLabel,
    required this.isYou,
  });

  final LeaderboardEntry entry;
  final String timeLabel;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isYou ? ZipColors.emberSoft : ZipColors.wall,
        borderRadius: BorderRadius.circular(14),
        border: isYou
            ? Border.all(color: ZipColors.ember.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          _leading(context),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: ZipColors.onInk),
                ),
                if (isYou)
                  Text(
                    AppStrings.youLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: ZipColors.ember),
                  ),
              ],
            ),
          ),
          Text(
            timeLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ZipColors.onInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leading(BuildContext context) {
    final rank = entry.rank;
    final asset = switch (rank) {
      1 => 'assets/medals/medal_gold.png',
      2 => 'assets/medals/medal_silver.png',
      3 => 'assets/medals/medal_bronze.png',
      _ => null,
    };
    if (asset != null) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _rankText(context),
        ),
      );
    }
    return SizedBox(width: 28, child: _rankText(context));
  }

  Widget _rankText(BuildContext context) {
    return Text(
      '${entry.rank}',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: ZipColors.onInk,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
