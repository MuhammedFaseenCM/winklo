import 'package:shared_preferences/shared_preferences.dart';

import '../../core/haptics/haptics_service.dart';
import '../../core/sfx/sfx_service.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Reminders live in shared_preferences. Sound and vibration go through
/// [SfxService] and [HapticsService], which keep the flag they gate on and
/// store it through the existing sfx and haptics repositories (the same
/// keys Profile used).
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(
    this._prefs, {
    required this._sfx,
    required this._haptics,
  });

  final SharedPreferences _prefs;
  final SfxService _sfx;
  final HapticsService _haptics;

  static const _dailyReadyKey = 'notif_daily_ready_enabled';
  static const _streakAtRiskKey = 'notif_streak_at_risk_enabled';
  static const _weeklyRecapKey = 'notif_weekly_recap_enabled';
  static const _announcementsKey = 'notif_announcements_enabled';
  static const _dailyReadyMinutesKey = 'notif_daily_ready_minutes';
  static const _streakMinutesKey = 'notif_streak_reminder_minutes';

  /// For readers created before this repository in DI (the notification
  /// repository's topic sync).
  static bool announcementsEnabledIn(SharedPreferences prefs) =>
      prefs.getBool(_announcementsKey) ?? true;

  @override
  bool get soundEnabled => _sfx.isEnabled;

  @override
  Future<void> setSoundEnabled(bool value) => _sfx.setEnabled(value);

  @override
  bool get vibrationEnabled => _haptics.isEnabled;

  @override
  Future<void> setVibrationEnabled(bool value) => _haptics.setEnabled(value);

  @override
  ReminderSettings get reminders {
    const defaults = ReminderSettings();
    return ReminderSettings(
      dailyReadyEnabled:
          _prefs.getBool(_dailyReadyKey) ?? defaults.dailyReadyEnabled,
      streakAtRiskEnabled:
          _prefs.getBool(_streakAtRiskKey) ?? defaults.streakAtRiskEnabled,
      weeklyRecapEnabled:
          _prefs.getBool(_weeklyRecapKey) ?? defaults.weeklyRecapEnabled,
      announcementsEnabled: announcementsEnabledIn(_prefs),
      dailyReadyMinutes: ReminderSettings.clampMinutes(
        _prefs.getInt(_dailyReadyMinutesKey) ?? defaults.dailyReadyMinutes,
      ),
      streakReminderMinutes: ReminderSettings.clampMinutes(
        _prefs.getInt(_streakMinutesKey) ?? defaults.streakReminderMinutes,
      ),
    );
  }

  @override
  Future<void> saveReminders(ReminderSettings settings) async {
    await _prefs.setBool(_dailyReadyKey, settings.dailyReadyEnabled);
    await _prefs.setBool(_streakAtRiskKey, settings.streakAtRiskEnabled);
    await _prefs.setBool(_weeklyRecapKey, settings.weeklyRecapEnabled);
    await _prefs.setBool(_announcementsKey, settings.announcementsEnabled);
    await _prefs.setInt(
      _dailyReadyMinutesKey,
      ReminderSettings.clampMinutes(settings.dailyReadyMinutes),
    );
    await _prefs.setInt(
      _streakMinutesKey,
      ReminderSettings.clampMinutes(settings.streakReminderMinutes),
    );
  }
}
