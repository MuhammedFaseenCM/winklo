import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/pending_level_clear.dart';
import '../../domain/repositories/pending_level_clear_repository.dart';

/// One JSON list per account and game, under
/// `pending_level_clears_{uid}_{game}`.
class PendingLevelClearRepositoryImpl implements PendingLevelClearRepository {
  PendingLevelClearRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String uid, String game) =>
      'pending_level_clears_${uid}_$game';

  @override
  List<PendingLevelClear> pending(String uid, String game) {
    final raw = _prefs.getString(_key(uid, game));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          ?PendingLevelClear.fromJson(item, game: game),
      ];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> keep(String uid, String game, PendingLevelClear clear) async {
    final all = pending(uid, game);
    final index = all.indexWhere((c) => c.levelId == clear.levelId);
    if (index >= 0) {
      if (!clear.betterThan(all[index])) return;
      all[index] = clear;
    } else {
      all.add(clear);
    }
    await _write(uid, game, all);
  }

  @override
  Future<void> drop(String uid, String game, String levelId) async {
    final all = pending(uid, game);
    final kept = all.where((c) => c.levelId != levelId).toList();
    if (kept.length == all.length) return;
    await _write(uid, game, kept);
  }

  Future<void> _write(
    String uid,
    String game,
    List<PendingLevelClear> clears,
  ) async {
    final key = _key(uid, game);
    if (clears.isEmpty) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(
      key,
      jsonEncode([for (final c in clears) c.toJson()]),
    );
  }
}
