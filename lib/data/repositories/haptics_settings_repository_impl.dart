import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/repositories/haptics_settings_repository.dart';

class HapticsSettingsRepositoryImpl implements HapticsSettingsRepository {
  HapticsSettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'haptics_enabled';

  @override
  bool get isEnabled => _prefs.getBool(_key) ?? true;

  @override
  Future<void> setEnabled(bool value) => _prefs.setBool(_key, value);
}
