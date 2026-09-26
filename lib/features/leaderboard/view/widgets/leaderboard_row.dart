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
    final rank = entry.rank;
    final isTop3 = rank >= 1 && rank <= 3;
    final accentBorder = switch (rank) {
      1 => const Color(0xFFFFD700).withValues(alpha: 0.8),
      2 => const Color(0xFFD4DFEB).withValues(alpha: 0.75),
      3 => const Color(0xFFE28B52).withValues(alpha: 0.75),
      _ => isYou
          ? ZipColors.ember.withValues(alpha: 0.65)
          : Colors.white.withValues(alpha: 0.08),
    };
    final accentWidth = switch (rank) {
      1 => 2.2,
      2 => 2.0,
      3 => 2.0,
      _ => isYou ? 1.5 : 1.0,
    };

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
        border: Border.all(
          color: accentBorder,
          width: accentWidth,
        ),
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
                Row(
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
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZipColors.ember.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: ZipColors.ember.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          AppStrings.youLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: ZipColors.ember,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
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
        width: 30,
        height: 30,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _rankText(context),
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
