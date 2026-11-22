import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/game_ids.dart';
import '../../domain/repositories/levels_game_preference_repository.dart';

class LevelsGamePreferenceRepositoryImpl
    implements LevelsGamePreferenceRepository {
  LevelsGamePreferenceRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'levels_selected_game';

  @override
  String read() {
    final stored = _prefs.getString(_key);
    return stored != null && levelGameIds.contains(stored)
        ? stored
        : GameIds.zip;
  }

  @override
  Future<void> write(String gameId) => _prefs.setString(_key, gameId);
}
