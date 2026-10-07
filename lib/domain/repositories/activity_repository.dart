abstract class ActivityRepository {
  DateTime? lastRecordedAt();

  Future<void> markRecorded(DateTime at);

  /// Upserts the day's activity doc. Returns `false` when skipped (e.g. Firebase
  /// not ready) so callers do not advance throttle / analytics. Throws on write
  /// failure after an attempt.
  Future<bool> recordOpen({
    required String uid,
    required String dayId,
    required String platform,
    required DateTime at,
  });
}
