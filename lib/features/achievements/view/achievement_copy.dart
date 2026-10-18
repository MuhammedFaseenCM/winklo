import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/achievements/achievement.dart';
import '../../../domain/game_ids.dart';

/// Display name of a daily game.
String gameTitle(String gameId) => switch (gameId) {
  GameIds.pathWords => AppStrings.pathWordsTitle,
  GameIds.sudoku => AppStrings.sudokuTitle,
  _ => AppStrings.zipTitle,
};

/// The badge's name, e.g. "7-day Zip streak".
String achievementTitle(Achievement a) => switch (a.kind) {
  AchievementKind.firstClear => AppStrings.achievementFirstClearTitle(
    gameTitle(a.gameId!),
  ),
  AchievementKind.streak => AppStrings.achievementStreakTitle(
    a.target,
    gameTitle(a.gameId!),
  ),
  AchievementKind.zipUnderMinute => AppStrings.achievementZipUnderMinuteTitle,
  AchievementKind.hintFreeWeek => AppStrings.achievementHintFreeWeekTitle,
  AchievementKind.flawlessSudokus => AppStrings.achievementFlawlessSudokusTitle,
  AchievementKind.perfectDay => AppStrings.achievementPerfectDayTitle,
};

/// How to earn it, e.g. "Clear Zip 7 days in a row".
String achievementCondition(Achievement a) => switch (a.kind) {
  AchievementKind.firstClear => AppStrings.achievementFirstClearCondition(
    gameTitle(a.gameId!),
  ),
  AchievementKind.streak => AppStrings.achievementStreakCondition(
    a.target,
    gameTitle(a.gameId!),
  ),
  AchievementKind.zipUnderMinute =>
    AppStrings.achievementZipUnderMinuteCondition,
  AchievementKind.hintFreeWeek => AppStrings.achievementHintFreeWeekCondition,
  AchievementKind.flawlessSudokus =>
    AppStrings.achievementFlawlessSudokusCondition,
  AchievementKind.perfectDay => AppStrings.achievementPerfectDayCondition,
};

IconData achievementIcon(Achievement a) => switch (a.kind) {
  AchievementKind.firstClear => switch (a.gameId) {
    GameIds.pathWords => Icons.route_rounded,
    GameIds.sudoku => Icons.grid_on_rounded,
    _ => Icons.bolt_rounded,
  },
  AchievementKind.streak => Icons.local_fire_department_rounded,
  AchievementKind.zipUnderMinute => Icons.timer_rounded,
  AchievementKind.hintFreeWeek => Icons.lightbulb_outline_rounded,
  AchievementKind.flawlessSudokus => Icons.auto_awesome_rounded,
  AchievementKind.perfectDay => Icons.wb_sunny_rounded,
};
