import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/achievements/achievement.dart';
import 'achievement_accent.dart';
import 'achievement_copy.dart';

/// Grouped badge case: first clears, streaks, then specials — each medal
/// enamelled in its own hue so Profile isn't a wall of ember discs.
class AchievementBadgeGrid extends StatelessWidget {
  const AchievementBadgeGrid({super.key, required this.unlocked});

  /// Ids of the unlocked achievements.
  final Set<String> unlocked;

  static const columns = 3;

  static List<Achievement> get _firstClears => [
    for (final a in Achievements.all)
      if (a.kind == AchievementKind.firstClear) a,
  ];

  static List<Achievement> get _streaks => [
    for (final a in Achievements.all)
      if (a.kind == AchievementKind.streak) a,
  ];

  static List<Achievement> get _specials => [
    for (final a in Achievements.all)
      if (a.kind != AchievementKind.firstClear &&
          a.kind != AchievementKind.streak)
        a,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: AppStrings.achievementsFirstClearsSection,
          accent: ZipColors.ember,
          achievements: _firstClears,
          unlocked: unlocked,
        ),
        const SizedBox(height: 14),
        _Section(
          title: AppStrings.achievementsStreaksSection,
          accent: const Color(0xFFFBBF24),
          achievements: _streaks,
          unlocked: unlocked,
        ),
        const SizedBox(height: 14),
        _Section(
          title: AppStrings.achievementsSpecialsSection,
          accent: const Color(0xFFA78BFA),
          achievements: _specials,
          unlocked: unlocked,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.accent,
    required this.achievements,
    required this.unlocked,
  });

  final String title;
  final Color accent;
  final List<Achievement> achievements;
  final Set<String> unlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: ZipColors.inkSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: latinTracking(0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (
          var start = 0;
          start < achievements.length;
          start += AchievementBadgeGrid.columns
        ) ...[
          if (start > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (
                var i = start;
                i < start + AchievementBadgeGrid.columns;
                i++
              ) ...[
                if (i > start) const SizedBox(width: 6),
                Expanded(
                  child: i < achievements.length
                      ? AchievementBadge(
                          achievement: achievements[i],
                          unlocked: unlocked.contains(achievements[i].id),
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
    final accent = achievementAccent(achievement);
    final medal = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked ? accent.gradient : null,
        color: unlocked ? null : ZipColors.paper,
        border: Border.all(
          color: unlocked
              ? accent.fill.withValues(alpha: 0.55)
              : ZipColors.outlineQuiet,
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [BoxShadow(color: accent.glow, blurRadius: 12, spreadRadius: -1)]
            : null,
      ),
      child: Icon(
        achievementIcon(achievement),
        size: 20,
        color: unlocked ? accent.icon : accent.fill.withValues(alpha: 0.45),
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
                      radius: 8,
                      backgroundColor: ZipColors.wall,
                      child: Icon(
                        Icons.lock_rounded,
                        size: 10,
                        color: ZipColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              unlocked ? title : condition,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: unlocked
                  ? theme.textTheme.labelSmall?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      fontSize: 10.5,
                    )
                  : theme.textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                      height: 1.15,
                      fontSize: 10,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
