/// When the soft update banner may show again after the player closed it.
abstract class UpdateBannerSnoozeRepository {
  /// The end of the current snooze, or null if the banner was never closed.
  DateTime? snoozedUntil();

  Future<void> snoozeUntil(DateTime until);
}
