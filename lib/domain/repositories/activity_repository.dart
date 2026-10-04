abstract class ActivityRepository {
  DateTime? lastRecordedAt();

  Future<void> markRecorded(DateTime at);

  Future<void> recordOpen({
    required String uid,
    required String dayId,
    required String platform,
    required DateTime at,
  });
}
