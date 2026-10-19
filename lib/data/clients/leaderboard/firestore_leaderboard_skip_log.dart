import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/firebase/firebase_bootstrap.dart';
import '../../leaderboard_root.dart';
import 'leaderboard_skip_log.dart';

/// Admin-only log of refused clears (read in winklo-admin's leaderboard page).
const leaderboardSkipsCollection = 'leaderboard_skips';

/// Every key a skip doc holds. Must match the rules' `validLeaderboardSkip`
/// whitelist exactly; `test/firestore/rules_key_whitelist_test.dart` pins
/// both.
const leaderboardSkipFirestoreKeys = {
  'uid',
  'gameId',
  'dayId',
  'timeSeconds',
  'reason',
  'usedHints',
  'hadMistakes',
  'displayName',
  'photoUrl',
  'avatarId',
  'appVersion',
  'buildNumber',
  'platform',
  'createdAt',
};

/// One doc per player, game and day; a later refusal replaces it.
String leaderboardSkipDocId(LeaderboardSkip skip) =>
    '${skip.uid}_${skip.gameId}_${skip.dayId}';

/// Fields for one skip doc (without `createdAt`).
@visibleForTesting
Map<String, Object?> leaderboardSkipFields(
  LeaderboardSkip skip, {
  required String appVersion,
  required String buildNumber,
  required String platform,
}) {
  final identity = skip.identity;
  return {
    'uid': skip.uid,
    'gameId': skip.gameId,
    'dayId': skip.dayId,
    'timeSeconds': skip.timeSeconds,
    'reason': skip.reason,
    'usedHints': skip.usedHints,
    'hadMistakes': skip.hadMistakes,
    if (identity != null) ...{
      'displayName': identity.displayName,
      'photoUrl': identity.photoUrl,
      'avatarId': identity.avatarId,
    },
    'appVersion': _clip(appVersion, 32),
    'buildNumber': _clip(buildNumber, 16),
    'platform': _clip(platform, 16),
  };
}

String _clip(String value, int max) =>
    value.length <= max ? value : value.substring(0, max);

class FirestoreLeaderboardSkipLog implements LeaderboardSkipLog {
  /// [packageInfo] is for tests.
  FirestoreLeaderboardSkipLog({
    this._firestore,
    Future<PackageInfo> Function()? packageInfo,
    this.timeout = const Duration(seconds: 10),
  }) : _packageInfo = packageInfo ?? PackageInfo.fromPlatform;

  final FirebaseFirestore? _firestore;
  final Future<PackageInfo> Function() _packageInfo;

  /// Bounds each Firestore call (offline, a write only completes on server
  /// ack; persistence keeps it queued).
  final Duration timeout;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  Future<void> record(LeaderboardSkip skip) async {
    try {
      final db = _db;
      if (db == null) return;
      if (await _onBoard(db, skip)) return;
      final info = await _packageInfo();
      await db
          .collection(leaderboardSkipsCollection)
          .doc(leaderboardSkipDocId(skip))
          .set({
            ...leaderboardSkipFields(
              skip,
              appVersion: info.version,
              buildNumber: info.buildNumber,
              platform: defaultTargetPlatform.name,
            ),
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(timeout);
    } catch (e, st) {
      debugPrint('Leaderboard skip log failed: $e');
      debugPrint('$st');
    }
  }

  /// Whether the player's daily entry already shows [skip]'s time or better.
  /// An unreadable entry (offline) counts as not on the board: a duplicate
  /// log costs less than a missing one.
  Future<bool> _onBoard(FirebaseFirestore db, LeaderboardSkip skip) async {
    try {
      final entry = await db
          .collection(leaderboardRootCollection())
          .doc(skip.gameId)
          .collection('daily')
          .doc(skip.dayId)
          .collection('entries')
          .doc(skip.uid)
          .get()
          .timeout(timeout);
      final time = entry.data()?['timeSeconds'];
      return time is int && time > 0 && time <= skip.timeSeconds;
    } catch (e) {
      debugPrint('Leaderboard skip log: board read failed: $e');
      return false;
    }
  }
}
