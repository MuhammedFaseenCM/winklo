import '../achievements/achievement_rules.dart';
import 'game_day_record.dart';
import 'game_streak.dart';

/// A player's cleared daily days (this device merged with their account's
/// `game_days`) and streaks, as stats and achievements read them.
class GameHistory {
  const GameHistory({
    required this.days,
    required this.streaks,
    required this.today,
    this.remoteIncluded = false,
    this.remoteFailed = false,
  });

  /// Cleared days of the daily games, by game then period.
  final List<GameDayRecord> days;

  /// Stored streak per game, decayed for [today] (as Home shows it).
  final Map<String, GameStreak> streaks;

  /// Local date the history was read on.
  final DateTime today;

  /// The account's remote days are merged in.
  final bool remoteIncluded;

  /// Signed in, but the account's remote days couldn't be read, so only this
  /// device's clears are counted.
  final bool remoteFailed;

  List<GameDayRecord> daysOf(String gameId) => [
    for (final day in days)
      if (day.gameId == gameId) day,
  ];

  GameStreak streakOf(String gameId) =>
      streaks[gameId] ?? GameStreak(gameId: gameId);

  AchievementInput get achievementInput => AchievementInput.fromDays(
    days,
    longestStreakByGame: {
      for (final MapEntry(:key, :value) in streaks.entries) key: value.longest,
    },
  );
}
