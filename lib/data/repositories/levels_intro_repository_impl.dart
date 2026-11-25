import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/game_ids.dart';
import '../../domain/repositories/levels_intro_repository.dart';

class LevelsIntroRepositoryImpl implements LevelsIntroRepository {
  LevelsIntroRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  static const _introKey = 'levels_intro_seen';
  static const _tipKey = 'levels_first_clear_tip_seen';
  static const _tabKey = 'levels_tab_seen';
  static const _lastGameKey = 'levels_last_game';

  Future<void> _setTrue(String key) async {
    await _prefs.setBool(key, true);
    _changes.add(null);
  }

  @override
  bool get introSeen => _prefs.getBool(_introKey) ?? false;

  @override
  Future<void> markIntroSeen() => _setTrue(_introKey);

  @override
  bool get firstClearTipSeen => _prefs.getBool(_tipKey) ?? false;

  @override
  Future<void> markFirstClearTipSeen() => _setTrue(_tipKey);

  @override
  bool get levelsTabSeen => _prefs.getBool(_tabKey) ?? false;

  @override
  Future<void> markLevelsTabSeen() => _setTrue(_tabKey);

  @override
  String? get lastGame {
    final stored = _prefs.getString(_lastGameKey);
    return stored != null && levelGameIds.contains(stored) ? stored : null;
  }

  @override
  Future<void> setLastGame(String gameId) async {
    if (!levelGameIds.contains(gameId)) return;
    await _prefs.setString(_lastGameKey, gameId);
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;
}
