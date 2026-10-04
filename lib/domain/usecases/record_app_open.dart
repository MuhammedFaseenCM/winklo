import '../entities/leaderboard_period.dart';
import '../repositories/activity_repository.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/auth_repository.dart';

class RecordAppOpen {
  RecordAppOpen(
    this._auth,
    this._activity,
    this._analytics, {
    this.throttle = const Duration(minutes: 5),
  });

  final AuthRepository _auth;
  final ActivityRepository _activity;
  final AnalyticsRepository _analytics;
  final Duration throttle;

  Future<void> call({DateTime? now, String? platform}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final at = now ?? DateTime.now();
    final last = _activity.lastRecordedAt();
    if (last != null && at.difference(last) < throttle) return;

    final resolvedPlatform = platform ?? 'other';
    try {
      await _activity.recordOpen(
        uid: user.uid,
        dayId: leaderboardDayId(at),
        platform: resolvedPlatform,
        at: at,
      );
      await _activity.markRecorded(at);
      await _analytics.logAppOpen(platform: resolvedPlatform);
    } catch (_) {
      // Best-effort: never block the app.
    }
  }
}
