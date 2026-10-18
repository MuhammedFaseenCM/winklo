import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/achievements/achievement.dart';
import '../../../domain/game_ids.dart';

/// Enamel colors for a badge — game hues for daily medals, specials get
/// their own metal.
@immutable
class AchievementAccent {
  const AchievementAccent({
    required this.fill,
    required this.fillDeep,
    required this.glow,
    required this.icon,
  });

  final Color fill;
  final Color fillDeep;
  final Color glow;
  final Color icon;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [fill, fillDeep],
  );
}

/// Zip ember, Path Words sky, Sudoku teal; specials diverge so the case
/// isn't a wall of one color.
AchievementAccent achievementAccent(Achievement a) {
  return switch (a.kind) {
    AchievementKind.firstClear => _gameAccent(a.gameId!),
    AchievementKind.streak => _streakAccent(a.gameId!, a.target),
    AchievementKind.zipUnderMinute => const AchievementAccent(
      fill: Color(0xFFFF8A4C),
      fillDeep: Color(0xFFE85A1C),
      glow: ZipColors.emberGlow,
      icon: ZipColors.onInk,
    ),
    AchievementKind.hintFreeWeek => const AchievementAccent(
      fill: Color(0xFFA78BFA),
      fillDeep: Color(0xFF7C3AED),
      glow: Color(0x4DA78BFA),
      icon: ZipColors.onInk,
    ),
    AchievementKind.flawlessSudokus => const AchievementAccent(
      fill: Color(0xFF5EEAD4),
      fillDeep: Color(0xFF0D9488),
      glow: Color(0x4D2DD4BF),
      icon: ZipColors.onInk,
    ),
    AchievementKind.perfectDay => const AchievementAccent(
      fill: Color(0xFFFBBF24),
      fillDeep: Color(0xFFD97706),
      glow: Color(0x4DFBBF24),
      icon: Color(0xFF1E293B),
    ),
  };
}

AchievementAccent _gameAccent(String gameId) => switch (gameId) {
  GameIds.pathWords => const AchievementAccent(
    fill: Color(0xFF7DD3FC),
    fillDeep: Color(0xFF0284C7),
    glow: ZipColors.skyGlow,
    icon: ZipColors.onInk,
  ),
  GameIds.sudoku => const AchievementAccent(
    fill: Color(0xFF6EE7B7),
    fillDeep: Color(0xFF059669),
    glow: Color(0x4D34D399),
    icon: ZipColors.onInk,
  ),
  _ => const AchievementAccent(
    fill: Color(0xFFFF8A4C),
    fillDeep: Color(0xFFE85A1C),
    glow: ZipColors.emberGlow,
    icon: ZipColors.onInk,
  ),
};

/// Longer streaks deepen toward a richer metal of the same game hue.
AchievementAccent _streakAccent(String gameId, int days) {
  final base = _gameAccent(gameId);
  if (days >= 100) {
    return AchievementAccent(
      fill: Color.lerp(base.fill, const Color(0xFFFDE68A), 0.35)!,
      fillDeep: Color.lerp(base.fillDeep, const Color(0xFFB45309), 0.4)!,
      glow: Color.lerp(base.glow, const Color(0x4DFBBF24), 0.5)!,
      icon: base.icon,
    );
  }
  if (days >= 30) {
    return AchievementAccent(
      fill: Color.lerp(base.fill, base.fillDeep, 0.15)!,
      fillDeep: Color.lerp(base.fillDeep, const Color(0xFF0F172A), 0.12)!,
      glow: base.glow,
      icon: base.icon,
    );
  }
  return base;
}
