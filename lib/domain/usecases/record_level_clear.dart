import '../logic/level_catalog.dart';
import '../logic/level_stars.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/level_progress_repository.dart';

/// Scores a cleared level run, keeps it in the player's progress and logs
/// `level_cleared`.
class RecordLevelClear {
  RecordLevelClear(this._progress, this._analytics);

  final LevelProgressRepository _progress;
  final AnalyticsRepository _analytics;

  Future<LevelClearResult> call({
    required String game,
    required LevelSlot slot,
    required bool usedHints,
    required int seconds,
  }) async {
    final stars = starsFor(
      usedHints: usedHints,
      seconds: seconds,
      targetSeconds: slot.entry.targetSeconds,
    );
    final result = await _progress.record(
      game,
      slot.entry.id,
      stars: stars,
      seconds: seconds,
    );
    await _analytics.logLevelCleared(
      gameId: game,
      levelId: slot.entry.id,
      world: slot.world.order,
      number: slot.number,
      stars: stars,
      firstClear: result.firstClear,
      improved: result.improved,
    );
    return result;
  }
}
