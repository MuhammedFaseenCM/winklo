import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';

class HintQuotaRepositoryImpl implements HintQuotaRepository {
  HintQuotaRepositoryImpl(
    this._prefs, {
    required Duration playPeriod,
    DateTime Function()? now,
  }) : _playPeriod = playPeriod,
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final Duration _playPeriod;
  final DateTime Function() _now;

  static const _prefix = 'hints_used_';

  String _key(String gameId) =>
      '$_prefix${gameId}_${PlayPeriod.id(_now(), _playPeriod)}';

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
    return HintQuotaRepository.cap - nextUsed;
  }
}
