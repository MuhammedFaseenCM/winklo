import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/play_mode_record_repository.dart';

/// SharedPreferences store for [PlayModeRecordRepository].
///
/// Keys share the score and hint prefixes (`best_time_`, `best_pts_`,
/// `hints_used_`), so the per-user purge and stash on sign-out cover them,
/// but the mode-first record keys never match a daily key, and no change
/// callback is wired: the progress sync never hears of these writes.
class PlayModeRecordRepositoryImpl implements PlayModeRecordRepository {
  PlayModeRecordRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _recordPrefixes = ['archive_', 'practice_', 'bonus_'];

  static String _checkedRecordKey(String recordKey) {
    if (!_recordPrefixes.any(recordKey.startsWith)) {
      throw ArgumentError.value(recordKey, 'recordKey', 'Not a mode record');
    }
    return recordKey;
  }

  static String _hintKey(String gameId, String runId) {
    if (!runId.startsWith('archive_') && runId != 'practice') {
      throw ArgumentError.value(runId, 'runId', 'Not an off-daily run');
    }
    return 'hints_used_${gameId}_$runId';
  }

  static String _timeKey(String recordKey) =>
      'best_time_${_checkedRecordKey(recordKey)}';

  static String _scoreKey(String recordKey) =>
      'best_pts_${_checkedRecordKey(recordKey)}';

  @override
  int? bestTimeSeconds(String recordKey) => _prefs.getInt(_timeKey(recordKey));

  @override
  Future<LocalBest> recordTime(String recordKey, int timeSeconds) async {
    final key = _timeKey(recordKey);
    final previous = _prefs.getInt(key);
    if (previous != null && previous <= timeSeconds) {
      return LocalBest(best: previous, previous: previous);
    }
    await _prefs.setInt(key, timeSeconds);
    return LocalBest(
      best: timeSeconds,
      previous: previous,
      improved: previous != null,
    );
  }

  @override
  int? bestScore(String recordKey) => _prefs.getInt(_scoreKey(recordKey));

  @override
  Future<LocalBest> recordScore(String recordKey, int score) async {
    final key = _scoreKey(recordKey);
    final previous = _prefs.getInt(key);
    if (previous != null && previous >= score) {
      return LocalBest(best: previous, previous: previous);
    }
    await _prefs.setInt(key, score);
    return LocalBest(
      best: score,
      previous: previous,
      improved: previous != null,
    );
  }

  @override
  int hintsUsed(String gameId, String runId) =>
      _prefs.getInt(_hintKey(gameId, runId)) ?? 0;

  @override
  Future<void> setHintsUsed(String gameId, String runId, int used) async {
    await _prefs.setInt(_hintKey(gameId, runId), used);
  }

  @override
  Future<void> clearHints(String gameId, String runId) async {
    await _prefs.remove(_hintKey(gameId, runId));
  }
}
