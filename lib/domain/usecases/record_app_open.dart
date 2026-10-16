import '../entities/leaderboard_period.dart';
import '../entities/recorded_open.dart';
import '../repositories/activity_repository.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/auth_repository.dart';

/// Records that the app was opened: the signed-in player's day doc, or the
/// guest's through the activity Worker.
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
    final at = now ?? DateTime.now();
    final dayId = leaderboardDayId(at);
    final resolvedPlatform = platform ?? 'other';
    try {
      final installId = await _activity.installId();
      final user = _auth.currentUser;
      final key = user == null ? 'g:$installId' : 'u:${user.uid}';
      // Skipped only for the same person on the same day: a sign-in right
      // after a guest open, or the first open past midnight, still counts.
      final last = _activity.lastRecorded();
      if (last != null &&
          last.key == key &&
          leaderboardDayId(last.at) == dayId &&
          at.difference(last.at) < throttle) {
        return;
      }

      final wrote = user == null
          ? await _activity.recordGuestOpen(
              installId: installId,
              dayId: dayId,
              platform: resolvedPlatform,
            )
          : await _activity.recordOpen(
              uid: user.uid,
              installId: installId,
              dayId: dayId,
              platform: resolvedPlatform,
              at: at,
            );
      // Skip throttle + FA when nothing was written (retry on next ping).
      if (!wrote) return;
      await _activity.markRecorded(RecordedOpen(at: at, key: key));
      await _analytics.logAppOpen(platform: resolvedPlatform);
    } catch (_) {
      // Best-effort: never block the app.
    }
  }
}
