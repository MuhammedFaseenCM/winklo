import '../entities/reminder_settings.dart';

/// Everything the Settings screen changes.
abstract class SettingsRepository {
  bool get soundEnabled;
  Future<void> setSoundEnabled(bool value);

  bool get vibrationEnabled;
  Future<void> setVibrationEnabled(bool value);

  ReminderSettings get reminders;
  Future<void> saveReminders(ReminderSettings settings);
}
