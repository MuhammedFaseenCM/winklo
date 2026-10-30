import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/repositories/level_progress_repository.dart';

/// SharedPreferences store for [LevelProgressRepository], one JSON value per
/// account and game (`level_progress_<uid>_<game>`), plus what was last
/// pushed (`level_progress_pushed_<uid>_<game>`).
class LevelProgressRepositoryImpl implements LevelProgressRepository {
  LevelProgressRepositoryImpl(
    this._prefs, {
    required String? Function() currentUid,
    void Function()? onChanged,
  }) : _currentUid = currentUid,
       _onChanged = onChanged;

  final SharedPreferences _prefs;
  final String? Function() _currentUid;

  /// Asks for a push-only progress sync (`ProgressChangeSignal.notify`).
  final void Function()? _onChanged;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();

  String get _owner => _currentUid() ?? 'signed_out';
  String _key(String game) => 'level_progress_${_owner}_$game';
  String _pushedKey(String game) => 'level_progress_pushed_${_owner}_$game';

  LevelProgress _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return LevelProgress.empty;
    try {
      return LevelProgress.parse(jsonDecode(raw)).progress;
    } on FormatException {
      return LevelProgress.empty;
    }
  }

  Future<void> _write(String key, LevelProgress progress) =>
      _prefs.setString(key, jsonEncode(progress.toJson()));

  @override
  LevelProgress progress(String game) => _read(_key(game));

  @override
  Future<LevelClearResult> record(
    String game,
    String levelId, {
    required int stars,
    required int seconds,
  }) async {
    final before = progress(game);
    final after = before.withRun(levelId, stars: stars, seconds: seconds);
    await _write(_key(game), after);
    _fire(askSync: true);
    return LevelClearResult(
      runStars: stars,
      previous: before[levelId],
      current: after[levelId]!,
    );
  }

  @override
  Future<void> restore(String game, LevelProgress merged) async {
    await _write(_key(game), merged);
    _fire(askSync: false);
  }

  @override
  bool needsPush(String game) =>
      !progress(game).sameAs(_read(_pushedKey(game)));

  @override
  Future<void> markPushed(String game, LevelProgress pushed) =>
      _write(_pushedKey(game), pushed);

  void _fire({required bool askSync}) {
    if (!_changes.isClosed) _changes.add(null);
    if (askSync) _onChanged?.call();
  }
}
