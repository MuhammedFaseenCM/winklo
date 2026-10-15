import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/leaderboard_proof.dart';
import '../../domain/logic/progress_merge.dart';
import '../../domain/repositories/progress_local_repository.dart';

/// Prefixes of every per-user progress key on the device: scores, clear meta,
/// boards and leaderboard proofs, streaks (and the freeze-saved notices),
/// hint quota, run drafts, sync markers, the achievements already announced
/// and the habit surfaces' state (the dismissed weekly recap).
const userProgressKeyPrefixes = [
  'best_',
  'clear_meta_',
  'clear_board_',
  'clear_proof_',
  'streak_',
  'hints_used_',
  'in_progress_',
  'sync_',
  'achievements_',
  'habit_',
];

class ProgressLocalRepositoryImpl implements ProgressLocalRepository {
  ProgressLocalRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _ownerKey = 'progress_owner_uid';
  static const _markerPrefix = 'sync_';

  /// One JSON blob per stashed uid. Not a [userProgressKeyPrefixes] prefix, so
  /// purging the live progress keeps every stash.
  static const _stashPrefix = 'progress_stash_';

  static String _stashKey(String uid) => '$_stashPrefix$uid';

  /// Stored as `sync_<key>`, e.g. `sync_day_zip_20261007`, `sync_lb_…`,
  /// `sync_streak_zip`.
  static String _markerKey(String key) => '$_markerPrefix$key';

  @override
  String? get ownerUid {
    final uid = _prefs.getString(_ownerKey);
    return uid == null || uid.isEmpty ? null : uid;
  }

  @override
  Future<void> setOwnerUid(String uid) async {
    await _prefs.setString(_ownerKey, uid);
  }

  /// Leaves [ownerUid] alone; the caller records the new owner after purging.
  @override
  Future<void> purgeUserProgress() async {
    final keys = _userProgressKeys.toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }

  Iterable<String> get _userProgressKeys =>
      _prefs.getKeys().where((k) => userProgressKeyPrefixes.any(k.startsWith));

  /// Stored as `{key: [type, value]}` so each value is restored with its
  /// SharedPreferences type.
  @override
  Future<void> stashUserProgress(String uid) async {
    final entries = <String, List<Object>>{};
    for (final key in _userProgressKeys) {
      final value = _prefs.get(key);
      final tagged = switch (value) {
        final bool v => ['b', v],
        final int v => ['i', v],
        final double v => ['d', v],
        final String v => ['s', v],
        final List<Object?> v => ['l', v.whereType<String>().toList()],
        _ => null,
      };
      if (tagged != null) entries[key] = tagged;
    }
    if (entries.isEmpty) return;
    await _prefs.setString(_stashKey(uid), jsonEncode(entries));
  }

  @override
  Future<bool> restoreStashedProgress(String uid) async {
    final raw = _prefs.getString(_stashKey(uid));
    if (raw == null) return false;
    var restored = false;
    try {
      final entries = jsonDecode(raw);
      if (entries is Map<String, dynamic>) {
        for (final MapEntry(:key, :value) in entries.entries) {
          if (!userProgressKeyPrefixes.any(key.startsWith)) continue;
          if (await _restoreValue(key, value)) restored = true;
        }
      }
    } catch (e) {
      debugPrint('Progress stash for $uid unreadable: $e');
    }
    await _prefs.remove(_stashKey(uid));
    return restored;
  }

  Future<bool> _restoreValue(String key, Object? tagged) async {
    if (tagged is! List || tagged.length != 2) return false;
    final value = tagged[1];
    switch (tagged[0]) {
      case 'b' when value is bool:
        return _prefs.setBool(key, value);
      case 'i' when value is int:
        return _prefs.setInt(key, value);
      case 'd' when value is num:
        return _prefs.setDouble(key, value.toDouble());
      case 's' when value is String:
        return _prefs.setString(key, value);
      case 'l' when value is List:
        return _prefs.setStringList(key, value.whereType<String>().toList());
    }
    return false;
  }

  @override
  Future<void> forgetUserProgress(String uid) async {
    final owner = ownerUid;
    if (owner == null || owner == uid) {
      await purgeUserProgress();
      await _prefs.remove(_ownerKey);
    }
    await _prefs.remove(_stashKey(uid));
    await _prefs.remove(_historyUploadedKey(uid));
  }

  @override
  String? pushedSignature(String key) => _prefs.getString(_markerKey(key));

  @override
  Future<void> setPushedSignature(String key, String signature) async {
    await _prefs.setString(_markerKey(key), signature);
  }

  /// `clear_proof_<daily mode key>`, e.g. `clear_proof_zip_daily_20261007`:
  /// the proof's JSON, next to the clear's `clear_meta_` and `clear_board_`.
  static String _clearProofKey(String gameId, String playId) =>
      'clear_proof_${modeKeyFor(gameId, playId)}';

  @override
  LeaderboardProof? clearProof(String gameId, String playId) {
    final raw = _prefs.getString(_clearProofKey(gameId, playId));
    if (raw == null) return null;
    try {
      return LeaderboardProof.fromJson(gameId, jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setClearProof(
    String gameId,
    String playId,
    LeaderboardProof proof,
  ) async {
    await _prefs.setString(
      _clearProofKey(gameId, playId),
      jsonEncode(proof.toJson()),
    );
  }

  /// Not a [userProgressKeyPrefixes] prefix: each uid keeps its flag when
  /// another account's progress replaces the live keys.
  static String _historyUploadedKey(String uid) => 'history_uploaded_$uid';

  @override
  bool isHistoryUploaded(String uid) =>
      uid.isNotEmpty && (_prefs.getBool(_historyUploadedKey(uid)) ?? false);

  @override
  Future<void> setHistoryUploaded(String uid) async {
    if (uid.isEmpty) return;
    await _prefs.setBool(_historyUploadedKey(uid), true);
  }
}
