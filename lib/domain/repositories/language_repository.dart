import '../entities/app_language.dart';

/// The Settings language choice.
abstract interface class LanguageRepository {
  AppLanguage get language;
  Future<void> setLanguage(AppLanguage language);
}
