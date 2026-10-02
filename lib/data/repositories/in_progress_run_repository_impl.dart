import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/in_progress_run.dart';
import '../../domain/repositories/in_progress_run_repository.dart';

class InProgressRunRepositoryImpl implements InProgressRunRepository {
  InProgressRunRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static String keyFor({required String gameId, required String playId}) =>
      'in_progress_${gameId}_$playId';

  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async {
    final raw = _prefs.getString(keyFor(gameId: gameId, playId: playId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final run = InProgressRun.fromJson(Map<String, dynamic>.from(decoded));
      if (run.gameId != gameId || run.playId != playId) return null;
      return run;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(InProgressRun run) async {
    await _prefs.setString(
      keyFor(gameId: run.gameId, playId: run.playId),
      jsonEncode(run.toJson()),
    );
  }

  @override
  Future<void> clear({required String gameId, required String playId}) async {
    await _prefs.remove(keyFor(gameId: gameId, playId: playId));
  }
}
