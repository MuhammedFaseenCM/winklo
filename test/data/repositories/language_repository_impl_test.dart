import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/language_repository_impl.dart';
import 'package:winklo/domain/entities/app_language.dart';

void main() {
  Future<(LanguageRepositoryImpl, SharedPreferences)> repoWith([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (LanguageRepositoryImpl(prefs), prefs);
  }

  test('defaults to System', () async {
    final (repo, _) = await repoWith();
    expect(repo.language, AppLanguage.system);
  });

  test('stores and reads each choice', () async {
    final (repo, prefs) = await repoWith();
    for (final language in AppLanguage.values) {
      await repo.setLanguage(language);
      expect(repo.language, language);
      expect(LanguageRepositoryImpl(prefs).language, language);
    }
  });

  test('stores the choice under app_language', () async {
    final (repo, prefs) = await repoWith();
    await repo.setLanguage(AppLanguage.malayalam);
    expect(prefs.getString('app_language'), 'ml');
  });

  test('a stored value it does not know reads as System', () async {
    final (repo, _) = await repoWith({'app_language': 'klingon'});
    expect(repo.language, AppLanguage.system);
  });

  group('useStoredLanguage (isolates that never ran the app)', () {
    tearDown(() => AppStrings.use('en'));

    test('applies a stored Malayalam whatever the phone says', () async {
      final (_, prefs) = await repoWith({'app_language': 'ml'});
      useStoredLanguage(prefs, const ['en']);
      expect(AppStrings.languageCode, 'ml');
    });

    test('System follows the phone', () async {
      final (_, prefs) = await repoWith();
      useStoredLanguage(prefs, const ['ml', 'en']);
      expect(AppStrings.languageCode, 'ml');
    });

    test('a stored English stays English on a Malayalam phone', () async {
      final (_, prefs) = await repoWith({'app_language': 'en'});
      AppStrings.use('ml');
      useStoredLanguage(prefs, const ['ml']);
      expect(AppStrings.languageCode, 'en');
    });
  });
}
