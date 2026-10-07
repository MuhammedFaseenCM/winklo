import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_period.dart';
import '../../domain/failures.dart';
import '../../domain/game_ids.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../leaderboard_root.dart';

const _allowedGameIds = {GameIds.zip, GameIds.pathWords, GameIds.sudoku};

/// Maps ordered leaderboard rows to ranked [LeaderboardEntry] values.
///
/// Equal [timeSeconds] share a dense rank (1, 2, 2, 3). Rows must already be
/// ordered by time ascending (ties by earlier [updatedAt]).
List<LeaderboardEntry> mapLeaderboardRows(
  Iterable<({String id, Map<String, dynamic> data})> rows,
) {
  final entries = <LeaderboardEntry>[];
  var rank = 0;
  int? previousTime;
  for (final row in rows) {
    final data = row.data;
    final timeSeconds = data['timeSeconds'];
    if (timeSeconds is! int || timeSeconds <= 0) continue;
    final updatedAtRaw = data['updatedAt'];
    final updatedAt = updatedAtRaw is Timestamp
        ? updatedAtRaw.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final name = data['displayName'];
    final photo = data['photoUrl'];
    final avatar = data['avatarId'];
    if (previousTime == null || timeSeconds != previousTime) {
      rank += 1;
    }
    previousTime = timeSeconds;
    final usedHints = data['usedHints'];
    final hadMistakes = data['hadMistakes'];
    final currentStreak = data['currentStreak'];
    entries.add(
      LeaderboardEntry(
        uid: row.id,
        displayName: name is String && name.trim().isNotEmpty
            ? name.trim()
            : 'Player',
        photoUrl: photo is String && photo.isNotEmpty ? photo : null,
        avatarId: avatar is String && avatar.isNotEmpty ? avatar : null,
        timeSeconds: timeSeconds,
        updatedAt: updatedAt,
        rank: rank,
        usedHints: usedHints is bool ? usedHints : null,
        hadMistakes: hadMistakes is bool ? hadMistakes : null,
        currentStreak: currentStreak is int ? currentStreak : null,
      ),
    );
  }
  return entries;
}

/// Identity written onto leaderboard docs. Firestore profile wins when present.
({String displayName, String? photoUrl, String? avatarId})
resolveLeaderboardIdentity({
  required String? authDisplayName,
  String? authPhotoUrl,
  Map<String, dynamic>? profile,
}) {
  final profileName = profile?['displayName'];
  final authName = authDisplayName?.trim();
  final displayName = profileName is String && profileName.trim().isNotEmpty
      ? profileName.trim()
      : (authName != null && authName.isNotEmpty ? authName : 'Player');
  final photoUrl = profile != null && profile.containsKey('photoUrl')
      ? (profile['photoUrl'] is String &&
                (profile['photoUrl'] as String).isNotEmpty
            ? profile['photoUrl'] as String
            : null)
      : authPhotoUrl;
  final avatar = profile?['avatarId'];
  final avatarId = avatar is String && avatar.isNotEmpty ? avatar : null;
  return (displayName: displayName, photoUrl: photoUrl, avatarId: avatarId);
}

/// Identity to merge on leaderboard improve writes, or null when [profileDocumentRead]
/// is false so existing displayName/photoUrl/avatarId are not overwritten.
({String displayName, String? photoUrl, String? avatarId})?
leaderboardSubmitIdentity({
  required bool profileDocumentRead,
  required String? authDisplayName,
  String? authPhotoUrl,
  Map<String, dynamic>? profile,
}) {
  if (!profileDocumentRead) return null;
  return resolveLeaderboardIdentity(
    authDisplayName: authDisplayName,
    authPhotoUrl: authPhotoUrl,
    profile: profile,
  );
}

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl({this._firestore, this._auth});

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  FirebaseAuth? get _firebaseAuth {
    if (!FirebaseBootstrap.isReady) return null;
    return _auth ?? FirebaseAuth.instance;
  }

  void _assertGameId(String gameId) {
    if (!_allowedGameIds.contains(gameId)) {
      throw Failure('Unsupported leaderboard game: $gameId');
    }
  }

  CollectionReference<Map<String, dynamic>> _boardCollection({
    required FirebaseFirestore db,
    required String gameId,
    required LeaderboardPeriod period,
    required String? dayId,
  }) {
    final gameRef = db.collection(leaderboardRootCollection()).doc(gameId);
    switch (period) {
      case LeaderboardPeriod.allTime:
        return gameRef.collection('all_time');
      case LeaderboardPeriod.daily:
        final id = dayId ?? leaderboardDayId();
        return gameRef.collection('daily').doc(id).collection('entries');
    }
  }

  @override
  Stream<List<LeaderboardEntry>> watchBoard({
    required String gameId,
    required LeaderboardPeriod period,
    String? dayId,
  }) {
    _assertGameId(gameId);
    final db = _db;
    if (db == null) {
      return Stream.error(const Failure('Firebase is unavailable.'));
    }

    // Daily path uses a subcollection under the day doc so queries stay flat.
    final collection = _boardCollection(
      db: db,
      gameId: gameId,
      period: period,
      dayId: dayId,
    );

    return collection
        .orderBy('timeSeconds')
        .orderBy('updatedAt')
        .limit(50)
        .snapshots()
        .map(
          (snap) => mapLeaderboardRows(
            snap.docs.map((d) => (id: d.id, data: d.data())),
          ),
        );
  }

  @override
  Future<void> submitBestTime({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
  }) async {
    _assertGameId(gameId);
    if (timeSeconds <= 0) {
      throw const Failure('Invalid time for leaderboard.');
    }

    final db = _db;
    final auth = _firebaseAuth;
    final user = auth?.currentUser;
    if (db == null || user == null) {
      throw const Failure('Sign in required to join the leaderboard.');
    }

    Map<String, dynamic>? profile;
    var profileDocumentRead = false;
    try {
      profile = (await db.collection('users').doc(user.uid).get()).data();
      profileDocumentRead = true;
    } catch (e, st) {
      debugPrint('Leaderboard profile read failed: $e');
      debugPrint('$st');
    }
    final identity = leaderboardSubmitIdentity(
      profileDocumentRead: profileDocumentRead,
      authDisplayName: user.displayName,
      authPhotoUrl: user.photoURL,
      profile: profile,
    );
    final dayId = leaderboardDayId();

    final root = leaderboardRootCollection();
    final allTimeRef = db
        .collection(root)
        .doc(gameId)
        .collection('all_time')
        .doc(user.uid);
    final dailyRef = db
        .collection(root)
        .doc(gameId)
        .collection('daily')
        .doc(dayId)
        .collection('entries')
        .doc(user.uid);

    try {
      await _writeImproveOnly(
        allTimeRef,
        timeSeconds: timeSeconds,
        usedHints: usedHints,
        hadMistakes: hadMistakes,
        currentStreak: currentStreak,
        identity: identity,
      );
      await _writeImproveOnly(
        dailyRef,
        timeSeconds: timeSeconds,
        usedHints: usedHints,
        hadMistakes: hadMistakes,
        currentStreak: currentStreak,
        identity: identity,
      );
    } catch (e, st) {
      debugPrint('Leaderboard submit failed: $e');
      debugPrint('$st');
      throw Failure('Could not sync leaderboard.', cause: e);
    }
  }

  Future<void> _writeImproveOnly(
    DocumentReference<Map<String, dynamic>> ref, {
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
    ({String displayName, String? photoUrl, String? avatarId})? identity,
  }) async {
    await ref.firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final existing = snap.data()?['timeSeconds'];
      final timeImproved =
          !snap.exists || existing is! int || timeSeconds < existing;

      final payload = <String, dynamic>{'currentStreak': currentStreak};
      if (timeImproved) {
        payload['timeSeconds'] = timeSeconds;
        payload['updatedAt'] = FieldValue.serverTimestamp();
        payload['usedHints'] = usedHints;
        payload['hadMistakes'] = hadMistakes;
      }
      if (identity != null) {
        payload['displayName'] = identity.displayName;
        payload['photoUrl'] = identity.photoUrl;
        payload['avatarId'] = identity.avatarId;
      }
      tx.set(ref, payload, SetOptions(merge: true));
    });
  }
}
