import '../entities/game_streak.dart';

/// One daily game as the habit features see it today.
class GameHabitStatus {
  const GameHabitStatus({required this.streak, required this.clearedToday});

  /// Decayed to today, as `GetStreak` returns it.
  final GameStreak streak;

  /// Today's puzzle has a stored clear (the score lookup Home uses).
  final bool clearedToday;

  String get gameId => streak.gameId;

  /// Cleared by either record: the score, or the streak's last clear.
  bool clearedOn(String todayId) =>
      clearedToday || streak.lastClearedDateId == todayId;
}
