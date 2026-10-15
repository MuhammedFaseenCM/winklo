import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/haptics/haptics_service.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/data/repositories/settings_repository_impl.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';
import 'package:winklo/domain/repositories/haptics_settings_repository.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';

class _MockSfxSettings extends Mock implements SfxSettingsRepository {}

class _MockHapticsSettings extends Mock implements HapticsSettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSfxSettings sfxSettings;
  late _MockHapticsSettings hapticsSettings;
  late SfxService sfx;
  late HapticsService haptics;

  setUp(() {
    sfxSettings = _MockSfxSettings();
    hapticsSettings = _MockHapticsSettings();
    when(() => sfxSettings.isEnabled).thenReturn(true);
    when(() => sfxSettings.setEnabled(any())).thenAnswer((_) async {});
    when(() => hapticsSettings.isEnabled).thenReturn(false);
    when(() => hapticsSettings.setEnabled(any())).thenAnswer((_) async {});
    sfx = SfxService(settings: sfxSettings);
    haptics = HapticsService(settings: hapticsSettings, perform: (_) async {});
  });

  Future<SettingsRepositoryImpl> repoWith([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SettingsRepositoryImpl(
      await SharedPreferences.getInstance(),
      sfx: sfx,
      haptics: haptics,
    );
  }

  test('reminders default to everything on at 08:00 and 20:00', () async {
    final repo = await repoWith();
    expect(repo.reminders, const ReminderSettings());
  });

  test('reminders round-trip', () async {
    final repo = await repoWith();
    const changed = ReminderSettings(
      dailyReadyEnabled: false,
      streakAtRiskEnabled: true,
      weeklyRecapEnabled: false,
      announcementsEnabled: false,
      dailyReadyMinutes: 7 * 60 + 30,
      streakReminderMinutes: 21 * 60,
    );
    await repo.saveReminders(changed);
    expect(repo.reminders, changed);
    expect((await repoWith()).reminders, isNot(changed)); // fresh prefs
  });

  test('stored times outside the day are clamped', () async {
    final repo = await repoWith({
      'notif_daily_ready_minutes': -20,
      'notif_streak_reminder_minutes': 99999,
    });
    expect(repo.reminders.dailyReadyMinutes, 0);
    expect(repo.reminders.streakReminderMinutes, 24 * 60 - 1);
  });

  test('announcementsEnabledIn reads the stored flag', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(SettingsRepositoryImpl.announcementsEnabledIn(prefs), isTrue);
    final repo = SettingsRepositoryImpl(prefs, sfx: sfx, haptics: haptics);
    await repo.saveReminders(
      const ReminderSettings(announcementsEnabled: false),
    );
    expect(SettingsRepositoryImpl.announcementsEnabledIn(prefs), isFalse);
  });

  test('sound and vibration go through the services', () async {
    final repo = await repoWith();
    expect(repo.soundEnabled, isTrue);
    expect(repo.vibrationEnabled, isFalse);

    await repo.setSoundEnabled(false);
    await repo.setVibrationEnabled(true);

    expect(sfx.isEnabled, isFalse);
    expect(haptics.isEnabled, isTrue);
    expect(repo.soundEnabled, isFalse);
    expect(repo.vibrationEnabled, isTrue);
    verify(() => sfxSettings.setEnabled(false)).called(1);
    verify(() => hapticsSettings.setEnabled(true)).called(1);
  });
}
