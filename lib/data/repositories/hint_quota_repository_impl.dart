import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

class HintQuotaRepositoryImpl implements HintQuotaRepository {
  HintQuotaRepositoryImpl(
    this._prefs, {
    required Duration playPeriod,
    DateTime Function()? now,
    this._onChanged,
  }) : _playPeriod = playPeriod,
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final Duration _playPeriod;
  final DateTime Function() _now;

  /// Called after [tryConsume] spends a hint (DI wires it to the debounced
  /// progress push). [restoreUsed] never calls it, so a sync restore cannot
  /// feed back into another push.
  final void Function()? _onChanged;

  static const _prefix = 'hints_used_';

  String _key(String gameId) =>
      _keyFor(gameId, PlayPeriod.id(_now(), _playPeriod));

  String _keyFor(String gameId, String playId) => '$_prefix${gameId}_$playId';

  int _used(String gameId) => _prefs.getInt(_key(gameId)) ?? 0;

  @override
  int remaining(String gameId) {
    final left = HintQuotaRepository.cap - _used(gameId);
    return left < 0 ? 0 : left;
  }

  @override
  Future<int> tryConsume(String gameId) async {
    final left = remaining(gameId);
    if (left <= 0) return 0;
    final nextUsed = _used(gameId) + 1;
    await _prefs.setInt(_key(gameId), nextUsed);
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
