import 'package:bloc/bloc.dart';

import '../../../domain/entities/reminder_settings.dart';
import '../../../domain/repositories/settings_repository.dart';
import '../../../domain/usecases/save_reminder_settings.dart';
import 'settings_state.dart';

/// The Settings screen. Every change shows at once and is stored (reminder
/// changes also replan the notifications).
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({required this._settings, required this._saveReminders})
    : super(
        SettingsState(
          soundEnabled: _settings.soundEnabled,
          vibrationEnabled: _settings.vibrationEnabled,
          reminders: _settings.reminders,
        ),
      );

  final SettingsRepository _settings;
  final SaveReminderSettings _saveReminders;

  Future<void> setSound(bool enabled) async {
    emit(state.copyWith(soundEnabled: enabled));
    await _settings.setSoundEnabled(enabled);
  }

  Future<void> setVibration(bool enabled) async {
    emit(state.copyWith(vibrationEnabled: enabled));
    await _settings.setVibrationEnabled(enabled);
  }

  Future<void> setDailyReady(bool enabled) =>
      _update(state.reminders.copyWith(dailyReadyEnabled: enabled));

  Future<void> setStreakAtRisk(bool enabled) =>
      _update(state.reminders.copyWith(streakAtRiskEnabled: enabled));

  Future<void> setWeeklyRecap(bool enabled) =>
      _update(state.reminders.copyWith(weeklyRecapEnabled: enabled));

  Future<void> setAnnouncements(bool enabled) =>
      _update(state.reminders.copyWith(announcementsEnabled: enabled));

  /// [minutes] after midnight.
  Future<void> setDailyReadyTime(int minutes) => _update(
    state.reminders.copyWith(
      dailyReadyMinutes: ReminderSettings.clampMinutes(minutes),
    ),
  );

  /// [minutes] after midnight.
  Future<void> setStreakReminderTime(int minutes) => _update(
    state.reminders.copyWith(
      streakReminderMinutes: ReminderSettings.clampMinutes(minutes),
    ),
  );

  Future<void> _update(ReminderSettings next) async {
    if (next == state.reminders) return;
    emit(state.copyWith(reminders: next));
    await _saveReminders(next);
  }
}
