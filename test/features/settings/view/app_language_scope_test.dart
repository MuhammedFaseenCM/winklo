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
import 'package:winklo/features/settings/view/app_language_scope.dart';
import 'package:winklo/features/settings/view/settings_screen.dart';

class _MockSettings extends Mock implements SettingsRepository {}

class _MockSave extends Mock implements SaveReminderSettings {}

class _MockLanguages extends Mock implements LanguageRepository {}

/// A stateful screen that reads copy in build and keeps a count.
class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _taps++),
    child: Text('${AppStrings.retry} $_taps'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late _MockSettings settings;
  late _MockSave save;
  late _MockLanguages languages;
  late int replans;

  setUpAll(() => registerFallbackValue(AppLanguage.system));

  setUp(() {
    settings = _MockSettings();
    save = _MockSave();
    languages = _MockLanguages();
    replans = 0;
    when(() => settings.soundEnabled).thenReturn(true);
    when(() => settings.vibrationEnabled).thenReturn(true);
    when(() => settings.reminders).thenReturn(const ReminderSettings());
    when(() => languages.language).thenReturn(AppLanguage.system);
    when(() => languages.setLanguage(any())).thenAnswer((_) async {});
  });

  tearDown(() => AppStrings.use('en'));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<SettingsRepository>.value(value: settings),
          RepositoryProvider<SaveReminderSettings>.value(value: save),
        ],
        child: BlocProvider(
          create: (_) => LocaleCubit(
            languages: languages,
            deviceLanguageCodes: () => [
              for (final locale in tester.platformDispatcher.locales)
                locale.languageCode,
            ],
            onLanguageChanged: () async => replans++,
          ),
          child: AppLanguageScope(
            builder: (context, locale) => MaterialApp(
              locale: locale,
              supportedLocales: AppLanguageScope.supportedLocales,
              localizationsDelegates: AppLanguageScope.localizationsDelegates,
              theme: buildAppTheme(),
              home: const Column(
                children: [
                  _Probe(),
                  Expanded(child: SettingsScreen()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String okLabel(WidgetTester tester) => MaterialLocalizations.of(
    tester.element(find.byType(_Probe)),
  ).okButtonLabel;

  testWidgets('choosing മലയാളം switches the whole app and keeps state', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    await pump(tester);
    await tester.tap(find.text('Retry 0'));
    await tester.pump();
    expect(find.text('Retry 1'), findsOneWidget);
    final englishOk = okLabel(tester);

    await tester.tap(find.text('മലയാളം'));
    await tester.pump();

    expect(find.text('വീണ്ടും ശ്രമിക്കൂ 1'), findsOneWidget);
    expect(find.text('ക്രമീകരണം'), findsOneWidget);
    expect(find.text('Retry 1'), findsNothing);
    expect(okLabel(tester), isNot(englishOk));
    expect(replans, 1);

    await tester.tap(find.text('English'));
    await tester.pump();
    expect(find.text('Retry 1'), findsOneWidget);
    expect(find.text(AppStrings.settingsTitle), findsOneWidget);
    expect(okLabel(tester), englishOk);
    expect(replans, 2);
  });

  testWidgets('System follows the phone when its languages change', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    await pump(tester);
    expect(find.text('Retry 0'), findsOneWidget);

    tester.platformDispatcher.localesTestValue = const [
      Locale('ml', 'IN'),
      Locale('en', 'US'),
    ];
    await tester.pump();

    expect(find.text('വീണ്ടും ശ്രമിക്കൂ 0'), findsOneWidget);
    expect(find.text('ഫോണിന്റെ ഭാഷ: മലയാളം'), findsOneWidget);
    expect(replans, 1);
  });
}
