import 'dart:async';

import '../entities/game_streak.dart';
import '../habit/freeze_saved_notice.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/streak_repository.dart';
import '../streak_calculator.dart';

class RecordDailyClear {
  RecordDailyClear(this._repo, {this._analytics, this._habit});

  final StreakRepository _repo;
  final AnalyticsRepository? _analytics;

  /// Keeps "your freeze saved your streak" for Home.
  final HabitRepository? _habit;

  Future<GameStreak> call({
    required String gameId,
    required String dateId,
  }) async {
    final stored = await _repo.getStreak(gameId);
    final result = StreakCalculator.dailyClear(streak: stored, todayId: dateId);
    final saved = await _repo.saveStreak(result.streak);
    if (result.freezeSpent) {
      unawaited(_analytics?.logStreakFreezeUsed(gameId: gameId));
      await _noteFreezeSaved(
        FreezeSavedNotice(gameId: gameId, days: result.streak.current),
      );
    }
    return saved;
  }

  /// Best effort: the clear itself is already stored.
  Future<void> _noteFreezeSaved(FreezeSavedNotice notice) async {
    try {
      await _habit?.addFreezeSavedNotice(notice);
    } catch (_) {}
  }
}
