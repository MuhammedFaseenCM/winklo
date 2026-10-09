import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

class HintQuotaRepositoryImpl implements HintQuotaRepository {
  HintQuotaRepositoryImpl(this._prefs, {this._onChanged});

  final SharedPreferences _prefs;

  /// Called after [tryConsume] spends a hint (DI wires it to the debounced
  /// progress push). [restoreUsed] never calls it, so a sync restore cannot
  /// feed back into another push.
  final void Function()? _onChanged;

  static const _prefix = 'hints_used_';

  String _keyFor(String gameId, String playId) => '$_prefix${gameId}_$playId';

  @override
  int remaining(String gameId, String playId) {
    final left = HintQuotaRepository.cap - usedFor(gameId, playId);
    return left < 0 ? 0 : left;
  }

  @override
  Future<int> tryConsume(String gameId, String playId) async {
    final left = remaining(gameId, playId);
    if (left <= 0) return 0;
    final nextUsed = usedFor(gameId, playId) + 1;
    await _prefs.setInt(_keyFor(gameId, playId), nextUsed);
    _onChanged?.call();
    return HintQuotaRepository.cap - nextUsed;
  }

  @override
  int usedFor(String gameId, String playId) =>
      _prefs.getInt(_keyFor(gameId, playId)) ?? 0;

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async {
    if (used <= usedFor(gameId, playId)) return false;
    await _prefs.setInt(_keyFor(gameId, playId), used);
    return true;
  }
}
