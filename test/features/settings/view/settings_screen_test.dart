import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_language.dart';
import 'package:winklo/domain/entities/reminder_settings.dart';
import 'package:winklo/domain/repositories/language_repository.dart';
import 'package:winklo/domain/repositories/settings_repository.dart';
import 'package:winklo/domain/usecases/save_reminder_settings.dart';
import 'package:winklo/features/settings/cubit/locale_cubit.dart';
import 'package:winklo/features/settings/view/settings_screen.dart';

import '../../../helpers/screenshot.dart';

class _MockSettings extends Mock implements SettingsRepository {}

class _MockSave extends Mock implements SaveReminderSettings {}

class _MockLanguages extends Mock implements LanguageRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late _MockSettings settings;
  late _MockSave save;
  late _MockLanguages languages;

  setUpAll(() {
    registerFallbackValue(const ReminderSettings());
    registerFallbackValue(AppLanguage.system);
  });

  setUp(() {
    settings = _MockSettings();
    save = _MockSave();
    when(() => settings.soundEnabled).thenReturn(true);
    when(() => settings.vibrationEnabled).thenReturn(true);
    when(() => settings.reminders).thenReturn(const ReminderSettings());
    when(() => settings.setSoundEnabled(any())).thenAnswer((_) async {});
    when(() => settings.setVibrationEnabled(any())).thenAnswer((_) async {});
    when(() => save(any())).thenAnswer((_) async {});
    languages = _MockLanguages();
    when(() => languages.language).thenReturn(AppLanguage.system);
    when(() => languages.setLanguage(any())).thenAnswer((_) async {});
  });

  tearDown(() => AppStrings.use('en'));

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    Key? boundary,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SettingsRepository>.value(value: settings),
          RepositoryProvider<SaveReminderSettings>.value(value: save),
        ],
        child: BlocProvider(
          create: (_) => LocaleCubit(
            languages: languages,
            deviceLanguageCodes: () => const ['en'],
          ),
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: buildAppTheme(),
              debugShowCheckedModeBanner: false,
              home: const SettingsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows sound, reminders and the language', (tester) async {
    await pump(tester, size: const Size(360, 1200));
    expect(find.text(AppStrings.settingsTitle), findsOneWidget);
    expect(
      find.text(AppStrings.settingsSoundSection.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.settingsRemindersSection.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(AppStrings.profileSoundEffects), findsOneWidget);
    expect(find.text(AppStrings.profileVibration), findsOneWidget);
    expect(find.text(AppStrings.settingsDailyReady), findsOneWidget);
    expect(find.text(AppStrings.settingsStreakAtRisk), findsOneWidget);
    expect(find.text(AppStrings.settingsWeeklyRecap), findsOneWidget);
    expect(find.text(AppStrings.settingsAnnouncements), findsOneWidget);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('8:00 PM'), findsOneWidget);
    expect(
      find.text(AppStrings.settingsWeeklyRecapHint('7:00 PM')),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.settingsLanguageSection.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(AppStrings.settingsLanguageSystem), findsOneWidget);
    expect(find.text('Follows your phone: English'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('മലയാളം'), findsOneWidget);
  });

  testWidgets('the sound switch is stored', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.profileSoundEffects));
    await tester.pump();
    verify(() => settings.setSoundEnabled(false)).called(1);
  });

  testWidgets('turning a reminder off saves it and dims its time', (
    tester,
  ) async {
    await pump(tester, size: const Size(360, 1200));
    await tester.tap(find.text(AppStrings.settingsDailyReady));
    await tester.pump();
    verify(
      () => save(const ReminderSettings(dailyReadyEnabled: false)),
    ).called(1);
    final timeRow = tester.widget<ListTile>(
      find.ancestor(of: find.text('8:00 AM'), matching: find.byType(ListTile)),
    );
    expect(timeRow.enabled, isFalse);
  });

  testWidgets('a time row opens the picker and saves the new time', (
    tester,
  ) async {
    await pump(tester, size: const Size(360, 1200));
    await tester.tap(find.text('8:00 PM'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    // Switch to text input and type 21:30.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '9');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    verify(
      () => save(const ReminderSettings(streakReminderMinutes: 21 * 60 + 30)),
    ).called(1);
  });

  testWidgets('screenshot at 360x640 lays out without overflow', (
    tester,
  ) async {
    await loadScreenshotFonts();
    const boundary = Key('settings');
    await pump(tester, boundary: boundary);
    expect(tester.takeException(), isNull);
    await saveScreenshot(tester, find.byKey(boundary), 'settings_360x640');

    // The rest of the list scrolls into view.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.settingsAnnouncements), findsOneWidget);
    expect(tester.takeException(), isNull);
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'settings_360x640_scrolled',
    );
  });

  testWidgets('choosing മലയാളം stores it and switches the copy', (
    tester,
  ) async {
    await pump(tester, size: const Size(360, 1400));
    await tester.tap(find.text('മലയാളം'));
    await tester.pump();
    verify(() => languages.setLanguage(AppLanguage.malayalam)).called(1);
    expect(AppStrings.languageCode, 'ml');
    final malayalam = tester.widget<RadioListTile<AppLanguage>>(
      find.widgetWithText(RadioListTile<AppLanguage>, 'മലയാളം'),
    );
    expect(
      RadioGroup.maybeOf<AppLanguage>(
        tester.element(find.text('മലയാളം')),
      )?.groupValue,
      malayalam.value,
    );
  });
}
