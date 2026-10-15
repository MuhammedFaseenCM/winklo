import '../entities/reminder_settings.dart';
import '../repositories/auth_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/settings_repository.dart';

/// Stores the player's reminder choices, keeps the announcements topic in
/// line, and replans the reminders.
class SaveReminderSettings {
  SaveReminderSettings({
    required this._settings,
    required this._notifications,
    required this._auth,
    required this._refresh,
  });

  final SettingsRepository _settings;
  final NotificationRepository _notifications;
  final AuthRepository _auth;

  /// Replans reminders and the widget (`RefreshHabitSurfaces`).
  final Future<void> Function() _refresh;

  Future<void> call(ReminderSettings next) async {
    final previous = _settings.reminders;
    await _settings.saveReminders(next);
    if (previous.announcementsEnabled != next.announcementsEnabled) {
      // Topics are only joined while signed in (sign-out leaves them); a
      // signed-out player who turns them on joins at the next sign-in.
      if (!next.announcementsEnabled) {
        await _notifications.setAnnouncementsSubscribed(false);
      } else if (_auth.currentUser != null) {
        await _notifications.setAnnouncementsSubscribed(true);
      }
    }
    try {
      await _refresh();
    } catch (_) {
      // The choice is stored; the next app open or clear replans.
    }
  }
}
