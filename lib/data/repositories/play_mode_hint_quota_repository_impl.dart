import '../../domain/repositories/hint_quota_repository.dart';
import '../../domain/repositories/play_mode_record_repository.dart';

/// An archive run's hints, counted in the mode records, so a past day never
/// spends a daily's hints and the progress sync never hears of them. The
/// game blocs start a fresh run at zero ([PlayModeRecordRepository.clearHints]).
class ArchiveHintQuotaRepositoryImpl implements HintQuotaRepository {
  ArchiveHintQuotaRepositoryImpl(this._records);

  final PlayModeRecordRepository _records;

  @override
  Future<int> consume(String gameId, String playId) async {
    final used = usedFor(gameId, playId) + 1;
    await _records.setHintsUsed(gameId, playId, used);
    return used;
  }

  @override
  int usedFor(String gameId, String playId) =>
      _records.hintsUsed(gameId, playId);

  /// Archive hints are never synced.
  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}

/// Practice hints: free ([HintPenalty.appliesTo]) and counted in memory only.
class UnlimitedHintQuotaRepositoryImpl implements HintQuotaRepository {
  final Map<String, int> _used = {};

  String _key(String gameId, String playId) => '$gameId|$playId';

  @override
  Future<int> consume(String gameId, String playId) async {
    final key = _key(gameId, playId);
    final used = (_used[key] ?? 0) + 1;
    _used[key] = used;
    return used;
  }

  @override
  int usedFor(String gameId, String playId) => _used[_key(gameId, playId)] ?? 0;

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}
