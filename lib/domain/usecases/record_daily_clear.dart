import 'dart:async';

import '../entities/game_streak.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/streak_repository.dart';
import '../streak_calculator.dart';

class RecordDailyClear {
  RecordDailyClear(this._repo, {this._analytics});

  final StreakRepository _repo;
  final AnalyticsRepository? _analytics;

  Future<GameStreak> call({
    required String gameId,
    required String dateId,
  }) async {
    final stored = await _repo.getStreak(gameId);
    final updated = StreakCalculator.applyDailyClear(
      streak: stored,
      todayId: dateId,
    );
    if (stored.freezeAvailable && !updated.freezeAvailable) {
      unawaited(_analytics?.logStreakFreezeUsed(gameId: gameId));
    }
    return _repo.saveStreak(updated);
  }
}
