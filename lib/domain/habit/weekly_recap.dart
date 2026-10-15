import '../app_calendar.dart';

/// One Monday-to-Sunday week of daily clears: "This week: 18 of 21 cleared,
/// best Zip 0:58, 5-day Sudoku streak".
class WeeklyRecap {
  const WeeklyRecap({
    required this.weekStartId,
    required this.cleared,
    required this.possible,
    this.bestGameId,
    this.bestSeconds,
    this.streakGameId,
    this.streakDays = 0,
  });

  /// Streaks shorter than this are left out of the recap.
  static const minStreakDays = 2;

  /// The week's Monday, `YYYYMMDD`.
  final String weekStartId;
  final int cleared;

  /// Seven days times the number of games.
  final int possible;

  /// The fastest clear of the week (null when none had a time).
  final String? bestGameId;
  final int? bestSeconds;

  /// The longest current streak, when it is at least [minStreakDays].
  final String? streakGameId;
  final int streakDays;

  bool get isEmpty => cleared == 0;

  /// Local midnight of the Monday of [day]'s week.
  static DateTime weekStart(DateTime day) {
    final local = AppCalendar.localWallClock(day);
    return DateTime(
      local.year,
      local.month,
      local.day - (local.weekday - DateTime.monday),
    );
  }

  /// Reads the week starting [weekStart] (a Monday) through the lookups.
  /// [gameIds] is the tie-break order. [currentStreaks] are as of now.
  factory WeeklyRecap.build({
    required DateTime weekStart,
    required List<String> gameIds,
    required bool Function(String gameId, String dateId) clearedOn,
    required int? Function(String gameId, String dateId) timeOn,
    required Map<String, int> currentStreaks,
  }) {
    var cleared = 0;
    String? bestGame;
    int? bestSeconds;
    for (final gameId in gameIds) {
      for (var i = 0; i < DateTime.daysPerWeek; i++) {
        final dateId = AppCalendar.dateIdCompact(
          DateTime(weekStart.year, weekStart.month, weekStart.day + i),
        );
        if (!clearedOn(gameId, dateId)) continue;
        cleared++;
        final time = timeOn(gameId, dateId);
        if (time == null || time <= 0) continue;
        if (bestSeconds == null || time < bestSeconds) {
          bestSeconds = time;
          bestGame = gameId;
        }
      }
    }

    String? streakGame;
    var streakDays = 0;
    for (final gameId in gameIds) {
      final days = currentStreaks[gameId] ?? 0;
      if (days > streakDays) {
        streakDays = days;
        streakGame = gameId;
      }
    }
    if (streakDays < minStreakDays) {
      streakGame = null;
      streakDays = 0;
    }

    return WeeklyRecap(
      weekStartId: AppCalendar.dateIdCompact(weekStart),
      cleared: cleared,
      possible: DateTime.daysPerWeek * gameIds.length,
      bestGameId: bestGame,
      bestSeconds: bestSeconds,
      streakGameId: streakGame,
      streakDays: streakDays,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WeeklyRecap &&
      other.weekStartId == weekStartId &&
      other.cleared == cleared &&
      other.possible == possible &&
      other.bestGameId == bestGameId &&
      other.bestSeconds == bestSeconds &&
      other.streakGameId == streakGameId &&
      other.streakDays == streakDays;

  @override
  int get hashCode => Object.hash(
    weekStartId,
    cleared,
    possible,
    bestGameId,
    bestSeconds,
    streakGameId,
    streakDays,
  );

  @override
  String toString() =>
      'WeeklyRecap($weekStartId, $cleared/$possible, best $bestGameId '
      '$bestSeconds, streak $streakGameId $streakDays)';
}
