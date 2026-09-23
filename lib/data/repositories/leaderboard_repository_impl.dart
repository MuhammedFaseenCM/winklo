import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_period.dart';
import '../../domain/failures.dart';
import '../../domain/game_ids.dart';
import '../../domain/repositories/leaderboard_repository.dart';

const _allowedGameIds = {GameIds.zip, GameIds.pathWords};

/// Maps ordered leaderboard rows to ranked [LeaderboardEntry] values.
List<LeaderboardEntry> mapLeaderboardRows(
  Iterable<({String id, Map<String, dynamic> data})> rows,
) {
  final entries = <LeaderboardEntry>[];
  for (final row in rows) {
    final data = row.data;
    final timeSeconds = data['timeSeconds'];
    if (timeSeconds is! int || timeSeconds <= 0) continue;
    final updatedAtRaw = data['updatedAt'];
    final updatedAt = updatedAtRaw is Timestamp
        ? updatedAtRaw.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final name = data['displayName'];
    entries.add(
      LeaderboardEntry(
        uid: row.id,
        displayName: name is String && name.trim().isNotEmpty
            ? name.trim()
            : 'Player',
        photoUrl: data['photoUrl'] as String?,
        timeSeconds: timeSeconds,
        updatedAt: updatedAt,
        rank: entries.length + 1,
      ),
    );
  }
  return entries;
}

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  LeaderboardRepositoryImpl({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore,
      _auth = auth;

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
    final gameRef = db.collection('leaderboards').doc(gameId);
    switch (period) {
      case LeaderboardPeriod.allTime:
        return gameRef.collection('all_time');
      case LeaderboardPeriod.daily:
        final id = dayId ?? utcLeaderboardDayId();
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

    final displayName = () {
      final name = user.displayName?.trim();
      if (name == null || name.isEmpty) return 'Player';
      return name;
    }();
    final photoUrl = user.photoURL;
    final dayId = utcLeaderboardDayId();

    final allTimeRef = db
        .collection('leaderboards')
        .doc(gameId)
        .collection('all_time')
        .doc(user.uid);
    final dailyRef = db
        .collection('leaderboards')
        .doc(gameId)
        .collection('daily')
        .doc(dayId)
        .collection('entries')
        .doc(user.uid);

    try {
      await _writeImproveOnly(
        allTimeRef,
        timeSeconds: timeSeconds,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      await _writeImproveOnly(
        dailyRef,
        timeSeconds: timeSeconds,
        displayName: displayName,
        photoUrl: photoUrl,
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
    required String displayName,
    required String? photoUrl,
  }) async {
    await ref.firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final existing = snap.data()?['timeSeconds'];
        if (existing is int && timeSeconds >= existing) {
          return;
        }
      }
      tx.set(ref, {
        'timeSeconds': timeSeconds,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
