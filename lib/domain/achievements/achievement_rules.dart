import '../entities/game_day_record.dart';
import '../game_ids.dart';
import '../stats/clear_days.dart';
import 'achievement.dart';

const _dailyGames = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

/// What the achievement rules read: each daily game's cleared days and its
/// stored longest streak.
class AchievementInput {
  const AchievementInput({
    required this.clearsByGame,
    this.longestStreakByGame = const {},
  });

  /// Groups [days] by game, keeping cleared days of the three daily games.
  factory AchievementInput.fromDays(
    Iterable<GameDayRecord> days, {
    Map<String, int> longestStreakByGame = const {},
  }) {
    final byGame = <String, List<GameDayRecord>>{};
    for (final day in days) {
      if (!day.cleared || !_dailyGames.contains(day.gameId)) continue;
      (byGame[day.gameId] ??= []).add(day);
    }
    return AchievementInput(
      clearsByGame: byGame,
      longestStreakByGame: longestStreakByGame,
    );
  }

  final Map<String, List<GameDayRecord>> clearsByGame;

  /// Stored longest streak per game (freezes included).
  final Map<String, int> longestStreakByGame;

  List<GameDayRecord> clearsOf(String gameId) => [
    for (final day in clearsByGame[gameId] ?? const <GameDayRecord>[])
      if (day.cleared) day,
  ];
}

/// Ids of every achievement [input] has earned.
Set<String> unlockedAchievementIds(AchievementInput input) {
  final clearDates = {
    for (final gameId in _dailyGames)
      gameId: {
        for (final day in input.clearsOf(gameId)) ?dateOfPlayId(day.playId),
      },
  };
  final hintFreeRuns = {
    for (final gameId in _dailyGames)
      gameId: longestDailyRun([
        for (final day in input.clearsOf(gameId))
          if (isHintFree(day)) ?dateOfPlayId(day.playId),
      ]),
  };

  int longestStreak(String gameId) {
    final stored = input.longestStreakByGame[gameId] ?? 0;
    final run = longestDailyRun(clearDates[gameId]!);
    return stored > run ? stored : run;
  }

  bool earned(Achievement a) {
    switch (a.kind) {
      case AchievementKind.firstClear:
        return input.clearsOf(a.gameId!).isNotEmpty;
      case AchievementKind.streak:
        return longestStreak(a.gameId!) >= a.target;
      case AchievementKind.zipUnderMinute:
        return input
            .clearsOf(GameIds.zip)
            .any((day) => day.timeSeconds! < a.target);
      case AchievementKind.hintFreeWeek:
        return hintFreeRuns.values.any((run) => run >= a.target);
      case AchievementKind.flawlessSudokus:
        return input.clearsOf(GameIds.sudoku).where(isFlawless).length >=
            a.target;
      case AchievementKind.perfectDay:
        final shared = clearDates[_dailyGames.first]!.where(
          (date) => _dailyGames.every((g) => clearDates[g]!.contains(date)),
        );
        return shared.isNotEmpty;
    }
  }

  return {
    for (final a in Achievements.all)
      if (earned(a)) a.id,
  };
}

/// Achievements in [unlocked] that aren't in [seen], in catalog order.
List<Achievement> newlyUnlocked({
  required Set<String> unlocked,
  required Set<String> seen,
}) => [
  for (final a in Achievements.all)
    if (unlocked.contains(a.id) && !seen.contains(a.id)) a,
];
