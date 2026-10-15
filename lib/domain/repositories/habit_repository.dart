import '../habit/freeze_saved_notice.dart';

/// Small habit state kept on the device: streaks a freeze saved (shown once
/// on Home) and the weekly recap card the player dismissed.
abstract class HabitRepository {
  /// Keeps [notice] until Home takes it; replaces an earlier one for the same
  /// game.
  Future<void> addFreezeSavedNotice(FreezeSavedNotice notice);

  /// The pending notices, oldest first, and forgets them.
  Future<List<FreezeSavedNotice>> takeFreezeSavedNotices();

  /// Monday (`YYYYMMDD`) of the recap week whose Home card was dismissed.
  String? get dismissedRecapWeek;

  Future<void> dismissRecapWeek(String weekStartId);
}
