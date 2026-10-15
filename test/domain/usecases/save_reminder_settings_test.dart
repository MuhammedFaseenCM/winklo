import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/notification_repository.dart';
import 'package:winklo/domain/repositories/settings_repository.dart';
import 'package:winklo/domain/usecases/save_reminder_settings.dart';

class _MockSettings extends Mock implements SettingsRepository {}

class _MockNotifications extends Mock implements NotificationRepository {}

class _MockAuth extends Mock implements AuthRepository {}

void main() {
  late _MockSettings settings;
  late _MockNotifications notifications;
  late _MockAuth auth;
  late ReminderSettings stored;
  late int refreshes;

  setUpAll(() => registerFallbackValue(const ReminderSettings()));

  setUp(() {
    settings = _MockSettings();
    notifications = _MockNotifications();
    auth = _MockAuth();
    stored = const ReminderSettings();
    refreshes = 0;
    when(() => settings.reminders).thenAnswer((_) => stored);
    when(() => settings.saveReminders(any())).thenAnswer((inv) async {
      stored = inv.positionalArguments.first as ReminderSettings;
    });
    when(
      () => notifications.setAnnouncementsSubscribed(any()),
    ).thenAnswer((_) async {});
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'A'));
  });

  SaveReminderSettings build() => SaveReminderSettings(
    settings: settings,
    notifications: notifications,
    auth: auth,
    refresh: () async => refreshes++,
  );

  test('saves and replans', () async {
    await build()(const ReminderSettings(dailyReadyMinutes: 9 * 60));
    expect(stored.dailyReadyMinutes, 9 * 60);
    expect(refreshes, 1);
    verifyNever(() => notifications.setAnnouncementsSubscribed(any()));
  });

  test('turning announcements off unsubscribes', () async {
    await build()(const ReminderSettings(announcementsEnabled: false));
    verify(() => notifications.setAnnouncementsSubscribed(false)).called(1);
  });

  test('turning them back on subscribes when signed in', () async {
    stored = const ReminderSettings(announcementsEnabled: false);
    await build()(const ReminderSettings());
    verify(() => notifications.setAnnouncementsSubscribed(true)).called(1);
  });

  test('signed out, turning them on waits for the next sign-in', () async {
    stored = const ReminderSettings(announcementsEnabled: false);
    when(() => auth.currentUser).thenReturn(null);
    await build()(const ReminderSettings());
    verifyNever(() => notifications.setAnnouncementsSubscribed(any()));
    expect(stored.announcementsEnabled, isTrue);
  });

  test('a failing replan does not fail the save', () async {
    final save = SaveReminderSettings(
      settings: settings,
      notifications: notifications,
      auth: auth,
      refresh: () async => throw StateError('plugin'),
    );
    await save(const ReminderSettings(weeklyRecapEnabled: false));
    expect(stored.weeklyRecapEnabled, isFalse);
  });
}
