import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/repositories/streak_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl(this._prefs, {this._onChanged});

  final SharedPreferences _prefs;

  /// Called after [saveStreak] changes the stored streak (DI wires it to the
  /// debounced progress push). [restoreStreak] never calls it, so a sync
  /// restore cannot feed back into another push.
  final void Function()? _onChanged;

  static String _currentKey(String gameId) => 'streak_current_$gameId';
  static String _longestKey(String gameId) => 'streak_longest_$gameId';
  static String _lastKey(String gameId) => 'streak_last_$gameId';
  static String _freezeKey(String gameId) => 'streak_freeze_$gameId';

  @override
  Future<GameStreak> getStreak(String gameId) async {
    return GameStreak(
      gameId: gameId,
      current: _prefs.getInt(_currentKey(gameId)) ?? 0,
      longest: _prefs.getInt(_longestKey(gameId)) ?? 0,
      lastClearedDateId: _prefs.getString(_lastKey(gameId)),
      freezeAvailable: _prefs.getBool(_freezeKey(gameId)) ?? true,
    );
  }

  @override
  Future<GameStreak> saveStreak(GameStreak streak) async {
    if (await _write(streak)) _onChanged?.call();
    return streak;
  }

  @override
  Future<bool> restoreStreak(GameStreak streak) => _write(streak);

  /// Writes all four keys when any stored value differs; returns whether it
  /// wrote.
  Future<bool> _write(GameStreak streak) async {
    final stored = await getStreak(streak.gameId);
    final same =
        _prefs.containsKey(_currentKey(streak.gameId)) &&
        _prefs.containsKey(_freezeKey(streak.gameId)) &&
        stored.current == streak.current &&
        stored.longest == streak.longest &&
        stored.lastClearedDateId == streak.lastClearedDateId &&
        stored.freezeAvailable == streak.freezeAvailable;
    if (same) return false;
    await _prefs.setInt(_currentKey(streak.gameId), streak.current);
    await _prefs.setInt(_longestKey(streak.gameId), streak.longest);
    final last = streak.lastClearedDateId;
    if (last == null) {
      await _prefs.remove(_lastKey(streak.gameId));
    } else {
      await _prefs.setString(_lastKey(streak.gameId), last);
    }
    await _prefs.setBool(_freezeKey(streak.gameId), streak.freezeAvailable);
    return true;
  }
}
