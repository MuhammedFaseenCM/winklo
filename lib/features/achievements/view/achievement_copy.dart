import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
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
    GameIds.pathWords => AppIcons.path,
    GameIds.sudoku => AppIcons.grid,
    _ => AppIcons.lightning,
  },
  AchievementKind.streak => AppIcons.streak,
  AchievementKind.zipUnderMinute => AppIcons.timer,
  AchievementKind.hintFreeWeek => AppIcons.noHints,
  AchievementKind.flawlessSudokus => AppIcons.sparkle,
  AchievementKind.perfectDay => AppIcons.sun,
};
