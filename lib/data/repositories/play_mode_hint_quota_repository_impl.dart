import '../../domain/repositories/hint_quota_repository.dart';
import '../../domain/repositories/play_mode_record_repository.dart';

/// An archive run's hints: [HintQuotaRepository.cap] per run, counted in the
/// mode records, so a past day never spends a daily's hints and the progress
/// sync never hears of them. The game blocs give a fresh run a full set
/// ([PlayModeRecordRepository.clearHints]).
class ArchiveHintQuotaRepositoryImpl implements HintQuotaRepository {
  ArchiveHintQuotaRepositoryImpl(this._records);

  final PlayModeRecordRepository _records;

  @override
  int remaining(String gameId, String playId) {
    final left = HintQuotaRepository.cap - usedFor(gameId, playId);
    return left < 0 ? 0 : left;
  }

  @override
  Future<int> tryConsume(String gameId, String playId) async {
    if (remaining(gameId, playId) <= 0) return 0;
    final used = usedFor(gameId, playId) + 1;
    await _records.setHintsUsed(gameId, playId, used);
    return HintQuotaRepository.cap - used;
  }

  @override
  int usedFor(String gameId, String playId) =>
      _records.hintsUsed(gameId, playId);

  /// Archive hints are never synced.
  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}

/// Practice hints: no limit. Counts down from [budget] in memory only, so a
/// screen that checks "fewer left than before" still sees each hint spent;
/// screens show the plain "Hint" label in practice.
class UnlimitedHintQuotaRepositoryImpl implements HintQuotaRepository {
  static const budget = 999;

  final Map<String, int> _used = {};

  String _key(String gameId, String playId) => '$gameId|$playId';

  @override
  int remaining(String gameId, String playId) =>
      budget - usedFor(gameId, playId);

  @override
  Future<int> tryConsume(String gameId, String playId) async {
    final key = _key(gameId, playId);
    final used = (_used[key] ?? 0) + 1;
    // Wrap long before zero: practice never runs out.
    _used[key] = used >= budget - 1 ? 0 : used;
    return remaining(gameId, playId);
  }

  @override
  int usedFor(String gameId, String playId) => _used[_key(gameId, playId)] ?? 0;

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}
