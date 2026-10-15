import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/app_language.dart';
import 'package:winklo/domain/repositories/language_repository.dart';
import 'package:winklo/features/settings/cubit/locale_cubit.dart';
import 'package:winklo/features/settings/cubit/locale_state.dart';

class _MockLanguages extends Mock implements LanguageRepository {}

void main() {
  late _MockLanguages languages;
  late List<String> phone;
  late int replans;

  setUpAll(() => registerFallbackValue(AppLanguage.system));

  setUp(() {
    languages = _MockLanguages();
    phone = ['en'];
    replans = 0;
    when(() => languages.language).thenReturn(AppLanguage.system);
    when(() => languages.setLanguage(any())).thenAnswer((_) async {});
  });

  tearDown(() => AppStrings.use('en'));

  LocaleCubit build({Future<void> Function()? onLanguageChanged}) =>
      LocaleCubit(
        languages: languages,
        deviceLanguageCodes: () => phone,
        onLanguageChanged:
            onLanguageChanged ??
            () async {
              replans++;
            },
      );

  group('on start', () {
    test('applies the stored choice to AppStrings', () {
      when(() => languages.language).thenReturn(AppLanguage.malayalam);
      final cubit = build();
      expect(
        cubit.state,
        const LocaleState(choice: AppLanguage.malayalam, languageCode: 'ml'),
      );
      expect(AppStrings.languageCode, 'ml');
      expect(replans, 0);
    });

    test('System follows a Malayalam phone', () {
      phone = ['ml', 'en'];
      final cubit = build();
      expect(cubit.state.choice, AppLanguage.system);
      expect(cubit.state.languageCode, 'ml');
      expect(AppStrings.languageCode, 'ml');
    });

    test('System on a phone in another language reads English', () {
      phone = ['ta'];
      expect(build().state.languageCode, 'en');
      expect(AppStrings.languageCode, 'en');
    });
  });

  group('choose', () {
    blocTest<LocaleCubit, LocaleState>(
      'Malayalam stores the choice, switches AppStrings and replans once',
      build: build,
      act: (cubit) => cubit.choose(AppLanguage.malayalam),
      expect: () => const [
        LocaleState(choice: AppLanguage.malayalam, languageCode: 'ml'),
      ],
      verify: (_) {
        verify(() => languages.setLanguage(AppLanguage.malayalam)).called(1);
        expect(AppStrings.languageCode, 'ml');
        expect(AppStrings.retry, isNot('Retry'));
        expect(replans, 1);
      },
    );

    blocTest<LocaleCubit, LocaleState>(
      'the current choice again does nothing',
      setUp: () =>
          when(() => languages.language).thenReturn(AppLanguage.english),
      build: build,
      act: (cubit) => cubit.choose(AppLanguage.english),
      expect: () => const <LocaleState>[],
      verify: (_) {
        verifyNever(() => languages.setLanguage(any()));
        expect(replans, 0);
      },
    );

    blocTest<LocaleCubit, LocaleState>(
      'English to System on an English phone stores it without replanning',
      setUp: () =>
          when(() => languages.language).thenReturn(AppLanguage.english),
      build: build,
      act: (cubit) => cubit.choose(AppLanguage.system),
      expect: () => const [
        LocaleState(choice: AppLanguage.system, languageCode: 'en'),
      ],
      verify: (_) {
        verify(() => languages.setLanguage(AppLanguage.system)).called(1);
        expect(replans, 0);
      },
    );

    blocTest<LocaleCubit, LocaleState>(
      'a failing replan leaves the switch in place',
      build: () => build(onLanguageChanged: () async => throw Exception('x')),
      act: (cubit) => cubit.choose(AppLanguage.malayalam),
      expect: () => const [
        LocaleState(choice: AppLanguage.malayalam, languageCode: 'ml'),
      ],
      verify: (_) => expect(AppStrings.languageCode, 'ml'),
    );
  });

  group('deviceLanguagesChanged', () {
    blocTest<LocaleCubit, LocaleState>(
      'System follows the phone into Malayalam and replans',
      build: build,
      act: (cubit) {
        phone = ['ml'];
        cubit.deviceLanguagesChanged();
      },
      expect: () => const [
        LocaleState(choice: AppLanguage.system, languageCode: 'ml'),
      ],
      verify: (_) {
        expect(AppStrings.languageCode, 'ml');
        expect(replans, 1);
        verifyNever(() => languages.setLanguage(any()));
      },
    );

    blocTest<LocaleCubit, LocaleState>(
      'a phone change that keeps the language does nothing',
      build: build,
      act: (cubit) {
        phone = ['en', 'ml'];
        cubit.deviceLanguagesChanged();
      },
      expect: () => const <LocaleState>[],
      verify: (_) => expect(replans, 0),
    );

    blocTest<LocaleCubit, LocaleState>(
      'with English chosen, the phone is ignored',
      setUp: () =>
          when(() => languages.language).thenReturn(AppLanguage.english),
      build: build,
      act: (cubit) {
        phone = ['ml'];
        cubit.deviceLanguagesChanged();
      },
      expect: () => const <LocaleState>[],
      verify: (_) {
        expect(AppStrings.languageCode, 'en');
        expect(replans, 0);
      },
    );
  });
}
