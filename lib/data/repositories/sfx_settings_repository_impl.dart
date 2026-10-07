import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';

class SfxSettingsRepositoryImpl implements SfxSettingsRepository {
  SfxSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'sfx_enabled';

  @override
  bool get isEnabled => _prefs.getBool(_key) ?? true;

  @override
  Future<void> setEnabled(bool value) => _prefs.setBool(_key, value);
}
