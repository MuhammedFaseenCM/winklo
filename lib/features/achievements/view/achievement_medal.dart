import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/achievements/achievement.dart';
import 'achievement_accent.dart';
import 'achievement_copy.dart';

/// A badge's round medal: game-colored enamel when earned, dimmed with a
/// lock when not. Decorative: the caller labels it for screen readers.
class AchievementMedal extends StatelessWidget {
  const AchievementMedal({
    super.key,
    required this.achievement,
    required this.unlocked,
    this.size = 48,
  });

  final Achievement achievement;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = achievementAccent(achievement);
    final medal = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked ? accent.gradient : null,
        color: unlocked ? null : ZipColors.paper,
        border: Border.all(
          color: unlocked
              ? accent.fill.withValues(alpha: 0.55)
              : ZipColors.outline,
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: accent.glow,
                  blurRadius: size * 0.3,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Icon(
        achievementIcon(achievement),
        size: size / 2,
        color: unlocked ? accent.icon : accent.fill.withValues(alpha: 0.45),
      ),
    );
    if (unlocked) return ExcludeSemantics(child: medal);
    final lock = size * 0.38;
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(opacity: 0.6, child: medal),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: lock,
              height: lock,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ZipColors.wall,
              ),
              child: Icon(
                Icons.lock_rounded,
                size: lock * 0.6,
                color: ZipColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
