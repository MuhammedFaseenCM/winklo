import '../../../domain/entities/reminder_settings.dart';

class SettingsState {
  const SettingsState({
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.reminders,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final ReminderSettings reminders;

  SettingsState copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    ReminderSettings? reminders,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      reminders: reminders ?? this.reminders,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.soundEnabled == soundEnabled &&
      other.vibrationEnabled == vibrationEnabled &&
      other.reminders == reminders;

  @override
  int get hashCode => Object.hash(soundEnabled, vibrationEnabled, reminders);

  @override
  String toString() =>
      'SettingsState(sound: $soundEnabled, vibration: $vibrationEnabled)';
}
