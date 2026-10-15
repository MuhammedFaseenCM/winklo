import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/achievements/achievement.dart';
import 'achievement_copy.dart';

/// Every badge, three to a row: unlocked ones lit with their name, locked
/// ones dimmed with how to earn them.
class AchievementBadgeGrid extends StatelessWidget {
  const AchievementBadgeGrid({super.key, required this.unlocked});

  /// Ids of the unlocked achievements.
  final Set<String> unlocked;

  static const columns = 3;

  @override
  Widget build(BuildContext context) {
    final all = Achievements.all;
    return Column(
      children: [
        for (var start = 0; start < all.length; start += columns) ...[
          if (start > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = start; i < start + columns; i++) ...[
                if (i > start) const SizedBox(width: 8),
                Expanded(
                  child: i < all.length
                      ? AchievementBadge(
                          achievement: all[i],
                          unlocked: unlocked.contains(all[i].id),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.achievement,
    required this.unlocked,
  });

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = achievementTitle(achievement);
    final condition = achievementCondition(achievement);
    final medal = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked ? ZipColors.emberGradient : null,
        color: unlocked ? null : ZipColors.paper,
        border: unlocked ? null : Border.all(color: ZipColors.outline),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: ZipColors.emberGlow.withValues(alpha: 0.4),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Icon(
        achievementIcon(achievement),
        size: 24,
        color: unlocked ? ZipColors.onInk : ZipColors.inkSoft,
      ),
    );
    return Semantics(
      container: true,
      label: title,
      value: unlocked ? null : '${AppStrings.achievementLocked}. $condition',
      excludeSemantics: true,
      child: Opacity(
        opacity: unlocked ? 1 : 0.55,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                medal,
                if (!unlocked)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: ZipColors.wall,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: ZipColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              unlocked ? title : condition,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: unlocked
                  ? theme.textTheme.labelMedium?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    )
                  : theme.textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                      height: 1.25,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
