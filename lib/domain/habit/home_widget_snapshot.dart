import '../app_calendar.dart';
import '../streak_calculator.dart';
import 'game_habit_status.dart';

/// What a game's row on the home-screen widget shows.
enum HomeWidgetMark {
  /// ✓: today's puzzle is cleared.
  cleared,

  /// 🔥N: a streak waiting for today's clear.
  streak,

  /// Nothing cleared and no streak.
  play,
}

class HomeWidgetLine {
  const HomeWidgetLine({
    required this.gameId,
    required this.mark,
    this.streak = 0,
  });

  final String gameId;
  final HomeWidgetMark mark;

  /// Days, for [HomeWidgetMark.streak].
  final int streak;

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetLine &&
      other.gameId == gameId &&
      other.mark == mark &&
      other.streak == streak;

  @override
  int get hashCode => Object.hash(gameId, mark, streak);

  @override
  String toString() => 'HomeWidgetLine($gameId, ${mark.name}, $streak)';
}

/// The widget's rows for today, and for tomorrow in case the app isn't
/// opened before midnight (the widget picks by date on its own).
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.dayId,
    required this.nextDayId,
    required this.today,
    required this.tomorrow,
  });

  /// `YYYYMMDD` of the day [today] is for, and of the day after.
  final String dayId;
  final String nextDayId;
  final List<HomeWidgetLine> today;

  /// As tomorrow will look if today passes without another clear.
  final List<HomeWidgetLine> tomorrow;

  factory HomeWidgetSnapshot.build({
    required List<GameHabitStatus> games,
    required DateTime now,
  }) {
    final local = AppCalendar.localWallClock(now);
    final todayId = AppCalendar.dateIdCompact(local);
    final nextDayId = AppCalendar.dateIdCompact(
      DateTime(local.year, local.month, local.day + 1),
    );
    return HomeWidgetSnapshot(
      dayId: todayId,
      nextDayId: nextDayId,
      today: [
        for (final game in games)
          if (game.clearedOn(todayId))
            HomeWidgetLine(gameId: game.gameId, mark: HomeWidgetMark.cleared)
          else
            _streakOrPlay(game.gameId, game.streak.current),
      ],
      tomorrow: [
        for (final game in games)
          _streakOrPlay(
            game.gameId,
            StreakCalculator.atStakeTomorrow(
              streak: game.streak,
              todayId: todayId,
            ),
          ),
      ],
    );
  }

  static HomeWidgetLine _streakOrPlay(String gameId, int days) => days >= 1
      ? HomeWidgetLine(
          gameId: gameId,
          mark: HomeWidgetMark.streak,
          streak: days,
        )
      : HomeWidgetLine(gameId: gameId, mark: HomeWidgetMark.play);
}
