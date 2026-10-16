import '../entities/game_day_record.dart';
import '../entities/game_history.dart';
import '../entities/game_streak.dart';
import '../game_ids.dart';
import '../logic/local_game_day.dart';
import '../play_period.dart';
import 'clear_days.dart';

/// Dense fake history for [DevFlags.previewFullProgress]: every badge
/// unlocked and charts that look fully progressed.
///
/// Pure Dart — no Flutter. Not written to storage.
GameHistory previewFullProgressHistory({DateTime? today}) {
  final now = today ?? DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  const dayCount = 120;
  final days = <GameDayRecord>[];

  for (var i = 0; i < dayCount; i++) {
    final date = addDays(todayDate, -(dayCount - 1 - i));
    final playId = PlayPeriod.id(date, PlayPeriod.daily);
    final clearedAt = DateTime(date.year, date.month, date.day, 9, 30);

    for (final gameId in dailyProgressGameIds) {
      final timeSeconds = _timeSeconds(gameId: gameId, dayIndex: i);
      days.add(
        GameDayRecord(
          gameId: gameId,
          playId: playId,
          timeSeconds: timeSeconds,
          usedHints: false,
          hadMistakes: false,
          flagsKnown: true,
          hintsUsed: 0,
          clearedAt: clearedAt,
        ),
      );
    }
  }

  final todayId = PlayPeriod.id(todayDate, PlayPeriod.daily);
  final streaks = {
    for (final gameId in dailyProgressGameIds)
      gameId: GameStreak(
        gameId: gameId,
        current: 42,
        longest: 100,
        lastClearedDateId: todayId,
        freezeCount: 2,
      ),
  };

  return GameHistory(
    days: days,
    streaks: streaks,
    today: todayDate,
    remoteIncluded: true,
  );
}

/// Varied times so the histogram and trend have shape; Zip includes sub-minute.
int _timeSeconds({required String gameId, required int dayIndex}) {
  final wave = (dayIndex % 17) * 4;
  return switch (gameId) {
    GameIds.zip => dayIndex == 0 ? 48 : 70 + wave,
    GameIds.pathWords => 95 + wave,
    GameIds.sudoku => 180 + wave * 2,
    _ => 120 + wave,
  };
}
