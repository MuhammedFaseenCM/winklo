import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';
import 'package:winklo/domain/repositories/settings_repository.dart';
import 'package:winklo/domain/usecases/save_reminder_settings.dart';
import 'package:winklo/features/settings/cubit/settings_cubit.dart';
import 'package:winklo/features/settings/cubit/settings_state.dart';

class _MockSettings extends Mock implements SettingsRepository {}

class _MockSave extends Mock implements SaveReminderSettings {}

void main() {
  late _MockSettings settings;
  late _MockSave save;

  setUpAll(() => registerFallbackValue(const ReminderSettings()));

  setUp(() {
    settings = _MockSettings();
    save = _MockSave();
    when(() => settings.soundEnabled).thenReturn(true);
    when(() => settings.vibrationEnabled).thenReturn(false);
    when(() => settings.reminders).thenReturn(const ReminderSettings());
    when(() => settings.setSoundEnabled(any())).thenAnswer((_) async {});
    when(() => settings.setVibrationEnabled(any())).thenAnswer((_) async {});
    when(() => save(any())).thenAnswer((_) async {});
  });

  SettingsCubit build() =>
      SettingsCubit(settings: settings, saveReminders: save);

  test('starts from the stored settings', () {
    expect(
      build().state,
      const SettingsState(
        soundEnabled: true,
        vibrationEnabled: false,
        reminders: ReminderSettings(),
      ),
    );
  });

  blocTest<SettingsCubit, SettingsState>(
    'sound and vibration show at once and are stored',
    build: build,
    act: (cubit) async {
      await cubit.setSound(false);
      await cubit.setVibration(true);
    },
    expect: () => [
      const SettingsState(
        soundEnabled: false,
        vibrationEnabled: false,
        reminders: ReminderSettings(),
      ),
      const SettingsState(
        soundEnabled: false,
        vibrationEnabled: true,
        reminders: ReminderSettings(),
      ),
    ],
    verify: (_) {
      verify(() => settings.setSoundEnabled(false)).called(1);
      verify(() => settings.setVibrationEnabled(true)).called(1);
    },
  );

  blocTest<SettingsCubit, SettingsState>(
    'each reminder toggle is saved through SaveReminderSettings',
    build: build,
    act: (cubit) async {
      await cubit.setDailyReady(false);
      await cubit.setStreakAtRisk(false);
      await cubit.setWeeklyRecap(false);
      await cubit.setAnnouncements(false);
    },
    verify: (cubit) {
      const off = ReminderSettings(
        dailyReadyEnabled: false,
        streakAtRiskEnabled: false,
        weeklyRecapEnabled: false,
        announcementsEnabled: false,
      );
      expect(cubit.state.reminders, off);
      verify(
        () => save(const ReminderSettings(dailyReadyEnabled: false)),
      ).called(1);
      verify(() => save(off)).called(1);
      verify(() => save(any())).called(2);
    },
  );

  blocTest<SettingsCubit, SettingsState>(
    'times are saved, clamped to the day',
    build: build,
    act: (cubit) async {
      await cubit.setDailyReadyTime(7 * 60 + 30);
      await cubit.setStreakReminderTime(99999);
    },
    verify: (cubit) {
      expect(cubit.state.reminders.dailyReadyMinutes, 7 * 60 + 30);
      expect(cubit.state.reminders.streakReminderMinutes, 24 * 60 - 1);
      verify(() => save(any())).called(2);
    },
  );

  blocTest<SettingsCubit, SettingsState>(
    'an unchanged value saves nothing',
    build: build,
    act: (cubit) async {
      await cubit.setDailyReady(true);
      await cubit.setDailyReadyTime(8 * 60);
    },
    expect: () => <SettingsState>[],
    verify: (_) => verifyNever(() => save(any())),
  );
}
