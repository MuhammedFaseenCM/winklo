import 'dart:convert';

import 'package:winklo/domain/entities/clear_meta.dart';
import 'package:winklo/domain/repositories/score_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreRepositoryImpl implements ScoreRepository {
  ScoreRepositoryImpl(this._prefs, {this._onChanged});

  final SharedPreferences _prefs;

  /// Called after [submitScore] writes anything (DI wires it to the debounced
  /// progress push). [restoreBest] never calls it, so a sync restore cannot
  /// feed back into another push.
  final void Function()? _onChanged;

  static const _prefix = 'best_';
  static const _metaPrefix = 'clear_meta_';

  @override
  int getBestPoints(String modeKey) =>
      _prefs.getInt('${_prefix}pts_$modeKey') ?? 0;

  @override
  int? getBestTimeSeconds(String modeKey) =>
      _prefs.getInt('${_prefix}time_$modeKey');

  @override
  ClearMeta? getClearMeta(String modeKey) {
    final raw = _prefs.getString('$_metaPrefix$modeKey');
    if (raw == null) return null;
    try {
      return ClearMeta.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> submitScore({
    required String modeKey,
    required int points,
    int? timeSeconds,
    bool? usedHints,
    bool? hadMistakes,
  }) async {
    final pointsImproved = await _improvePoints(modeKey, points);
    final timeImproved = await _improveTime(modeKey, timeSeconds);
    final metaChanged = await _syncMeta(
      modeKey,
      timeSeconds: timeSeconds,
      timeImproved: timeImproved,
      meta: usedHints != null && hadMistakes != null
          ? ClearMeta(usedHints: usedHints, hadMistakes: hadMistakes)
          : null,
    );
    if (pointsImproved || timeImproved || metaChanged) _onChanged?.call();
    return pointsImproved || timeImproved;
  }

  @override
  Future<bool> restoreBest({
    required String modeKey,
    int? points,
    int? timeSeconds,
    ClearMeta? meta,
  }) async {
    final pointsImproved =
        points != null && await _improvePoints(modeKey, points);
    final timeImproved = await _improveTime(modeKey, timeSeconds);
    final metaChanged = await _syncMeta(
      modeKey,
      timeSeconds: timeSeconds,
      timeImproved: timeImproved,
      meta: meta,
    );
    return pointsImproved || timeImproved || metaChanged;
  }

  Future<bool> _improvePoints(String modeKey, int points) async {
    if (points <= getBestPoints(modeKey)) return false;
    await _prefs.setInt('${_prefix}pts_$modeKey', points);
    return true;
  }

  Future<bool> _improveTime(String modeKey, int? timeSeconds) async {
    if (timeSeconds == null) return false;
    final prevTime = getBestTimeSeconds(modeKey);
    if (prevTime != null && timeSeconds >= prevTime) return false;
    await _prefs.setInt('${_prefix}time_$modeKey', timeSeconds);
    return true;
  }

  /// Meta describes the best-time run: write it when [timeSeconds] just became
  /// the best, or equals a best that has no meta yet. A new best without
  /// [meta] drops the old run's meta so it is never paired with the new time.
  Future<bool> _syncMeta(
    String modeKey, {
    required int? timeSeconds,
    required bool timeImproved,
    required ClearMeta? meta,
  }) async {
    if (timeSeconds == null) return false;
    final key = '$_metaPrefix$modeKey';
    final current = getClearMeta(modeKey);
    if (meta == null) {
      if (!timeImproved || !_prefs.containsKey(key)) return false;
      await _prefs.remove(key);
      return true;
    }
    final fillsMissing =
        current == null && getBestTimeSeconds(modeKey) == timeSeconds;
    if (!timeImproved && !fillsMissing) return false;
    if (current == meta) return false;
    await _prefs.setString(key, jsonEncode(meta.toJson()));
    return true;
  }
}
