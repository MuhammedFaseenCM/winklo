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
  static const _boardPrefix = 'clear_board_';

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
  String? getClearBoard(String modeKey) =>
      _prefs.getString('$_boardPrefix$modeKey');

  @override
  Future<bool> submitScore({
    required String modeKey,
    required int points,
    int? timeSeconds,
    bool? usedHints,
    bool? hadMistakes,
    String? board,
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
    final boardChanged = await _syncBoard(
      modeKey,
      timeSeconds: timeSeconds,
      timeImproved: timeImproved,
      board: board,
    );
    if (pointsImproved || timeImproved || metaChanged || boardChanged) {
      _onChanged?.call();
    }
    return pointsImproved || timeImproved;
  }

  @override
  Future<bool> restoreBest({
    required String modeKey,
    int? points,
    int? timeSeconds,
    ClearMeta? meta,
    String? board,
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
    final boardChanged = await _syncBoard(
      modeKey,
      timeSeconds: timeSeconds,
      timeImproved: timeImproved,
      board: board,
      replaceOnTie: true,
    );
    return pointsImproved || timeImproved || metaChanged || boardChanged;
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

  /// Same rule as [_syncMeta]: the board belongs to the best-time run. With
  /// [replaceOnTie] (restores) a [board] for a time equal to the best also
  /// replaces the stored one, so a device adopts the remote copy's board,
  /// which the rules keep fixed for that time.
  Future<bool> _syncBoard(
    String modeKey, {
    required int? timeSeconds,
    required bool timeImproved,
    required String? board,
    bool replaceOnTie = false,
  }) async {
    if (timeSeconds == null) return false;
    final key = '$_boardPrefix$modeKey';
    final current = getClearBoard(modeKey);
    if (board == null) {
      if (!timeImproved || current == null) return false;
      await _prefs.remove(key);
      return true;
    }
    final tiesBest = getBestTimeSeconds(modeKey) == timeSeconds;
    final fillsMissing = tiesBest && (current == null || replaceOnTie);
    if (!timeImproved && !fillsMissing) return false;
    if (current == board) return false;
    await _prefs.setString(key, board);
    return true;
  }
}
