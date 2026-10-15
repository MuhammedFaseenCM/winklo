import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings/app_strings.dart';
import '../../domain/entities/app_language.dart';
import '../../domain/repositories/language_repository.dart';

/// The choice lives in shared_preferences as `system`, `en` or `ml`.
class LanguageRepositoryImpl implements LanguageRepository {
  LanguageRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'app_language';

  @override
  AppLanguage get language => AppLanguage.fromStorageId(_prefs.getString(_key));

  @override
  Future<void> setLanguage(AppLanguage language) =>
      _prefs.setString(_key, language.storageId);
}

/// Puts [AppStrings] in the stored language, resolved against the phone's
/// [deviceLanguageCodes]. For isolates that never ran the app (the FCM
/// background handler), where `LocaleCubit` doesn't exist.
void useStoredLanguage(
  SharedPreferences prefs,
  List<String> deviceLanguageCodes,
) => AppStrings.use(
  resolveLanguageCode(
    LanguageRepositoryImpl(prefs).language,
    deviceLanguageCodes,
  ),
);
