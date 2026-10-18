import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/app_language.dart';

void main() {
  group('resolveLanguageCode', () {
    test('English and Malayalam ignore the phone', () {
      expect(resolveLanguageCode(AppLanguage.english, ['ml']), 'en');
      expect(resolveLanguageCode(AppLanguage.malayalam, ['en']), 'ml');
      expect(resolveLanguageCode(AppLanguage.malayalam, []), 'ml');
    });

    test('System picks the first phone language the app has', () {
      expect(resolveLanguageCode(AppLanguage.system, ['ml', 'en']), 'ml');
      expect(resolveLanguageCode(AppLanguage.system, ['en', 'ml']), 'en');
      expect(resolveLanguageCode(AppLanguage.system, ['hi', 'ml']), 'ml');
      expect(resolveLanguageCode(AppLanguage.system, ['hi', 'en']), 'en');
    });

    test('System falls back to English', () {
      expect(resolveLanguageCode(AppLanguage.system, ['ta']), 'en');
      expect(resolveLanguageCode(AppLanguage.system, []), 'en');
    });
  });

  group('storage ids', () {
    test('round-trip', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromStorageId(language.storageId), language);
      }
    });

    test('a missing or unknown id reads as System', () {
      expect(AppLanguage.fromStorageId(null), AppLanguage.system);
      expect(AppLanguage.fromStorageId('fr'), AppLanguage.system);
    });
  });
}
