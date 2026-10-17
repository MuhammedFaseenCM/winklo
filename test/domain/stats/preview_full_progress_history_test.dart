import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/domain/achievements/achievement_rules.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/logic/local_game_day.dart';
import 'package:winklo/domain/stats/game_stats.dart';
import 'package:winklo/domain/stats/preview_full_progress_history.dart';

void main() {
  test('preview history unlocks every badge and fills stats', () {
    final history = previewFullProgressHistory(today: DateTime(2026, 10, 15));
    final unlocked = unlockedAchievementIds(history.achievementInput);

    expect(unlocked, Achievements.all.map((a) => a.id).toSet());

    for (final gameId in dailyProgressGameIds) {
      final game = computeGameStats(
        gameId: gameId,
        days: history.daysOf(gameId),
        streak: history.streakOf(gameId),
        today: history.today,
      );
      expect(game.clears, greaterThan(50), reason: gameId);
      expect(game.longestStreak, greaterThanOrEqualTo(100), reason: gameId);
      expect(game.bestSeconds, isNotNull, reason: gameId);
      expect(game.histogram, isNotEmpty, reason: gameId);
      expect(game.calendar, isNotEmpty, reason: gameId);
      expect(game.trend, isNotEmpty, reason: gameId);
    }
    expect(
      computeGameStats(
        gameId: GameIds.zip,
        days: history.daysOf(GameIds.zip),
        streak: history.streakOf(GameIds.zip),
        today: history.today,
      ).bestSeconds,
      lessThan(60),
    );
  });
}
