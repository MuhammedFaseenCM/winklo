import '../entities/recorded_open.dart';

abstract class ActivityRepository {
  /// The last recorded open, or null before the first one (or when an older
  /// build recorded it without saying whose).
  RecordedOpen? lastRecorded();

  Future<void> markRecorded(RecordedOpen open);

  /// This install's ID: a random UUID v4, made on first use and kept.
  Future<String> installId();

  /// Upserts the signed-in player's day doc. Returns `false` when skipped
  /// (e.g. Firebase not ready) so callers do not advance throttle /
  /// analytics. Throws on write failure after an attempt.
  Future<bool> recordOpen({
    required String uid,
    required String installId,
    required String dayId,
    required String platform,
    required DateTime at,
  });

  /// Records a guest's open through the activity Worker. Returns `false` when
  /// skipped (no Worker configured). Throws when the Worker didn't record it.
  Future<bool> recordGuestOpen({
    required String installId,
    required String dayId,
    required String platform,
  });
}
