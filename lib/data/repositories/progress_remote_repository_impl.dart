import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/game_day_record.dart';
import '../../domain/entities/game_streak.dart';
import '../../domain/failures.dart';
import '../../domain/game_ids.dart';
import '../../domain/repositories/progress_remote_repository.dart';
import '../progress_collections.dart';

const _syncedGameIds = {GameIds.zip, GameIds.pathWords, GameIds.sudoku};

final _playIdPattern = RegExp(r'^[0-9]{8}([0-9]{4})?$');
final _dateIdPattern = RegExp(r'^[0-9]{8}$');

/// Upper bound the rules accept for `hintsUsed`.
const _maxHintsUsed = 50;

/// Every key the client may write on `users/{uid}/game_days/{dayKey}`.
///
/// Must match the rules' key whitelist exactly (see the `currentStreak`
/// incident): a key written here but missing there rejects the whole write.
const gameDayFirestoreKeys = {
  'gameId',
  'playId',
  'timeSeconds',
  'points',
  'usedHints',
  'hadMistakes',
  'flagsKnown',
  'hintsUsed',
  'clearedAt',
  'updatedAt',
};

/// Every key the client may write on `users/{uid}/game_streaks/{gameId}`.
const streakFirestoreKeys = {
  'current',
  'longest',
  'lastClearedDateId',
  'freezeAvailable',
  'updatedAt',
};

/// Doc id of a game day: `{gameId}_{playId}`.
String gameDayDocId(String gameId, String playId) => '${gameId}_$playId';

/// Firestore payload for [record]. Null fields are left out (merge writes keep
/// what the server already has); `clearedAt` is a concrete timestamp because
/// the rules type-check it.
Map<String, dynamic> gameDayToFirestore(GameDayRecord record) {
  final hintsUsed = record.hintsUsed.clamp(0, _maxHintsUsed);
  return {
    'gameId': record.gameId,
    'playId': record.playId,
    if (record.timeSeconds case final t? when t >= 0) 'timeSeconds': t,
    if (record.points case final p? when p >= 0) 'points': p,
    'usedHints': ?record.usedHints,
    'hadMistakes': ?record.hadMistakes,
    'flagsKnown': ?record.flagsKnown,
    'hintsUsed': hintsUsed,
    if (record.clearedAt case final at?) 'clearedAt': Timestamp.fromDate(at),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Parses a game day doc. Ids come from the caller (the doc path); malformed
/// fields read as absent. Returns null when [data] is null.
GameDayRecord? gameDayFromFirestore(
  Map<String, dynamic>? data, {
  required String gameId,
  required String playId,
}) {
  if (data == null) return null;
  return GameDayRecord(
    gameId: gameId,
    playId: playId,
    timeSeconds: _nonNegativeInt(data['timeSeconds']),
    points: _nonNegativeInt(data['points']),
    usedHints: _boolOrNull(data['usedHints']),
    hadMistakes: _boolOrNull(data['hadMistakes']),
    flagsKnown: _boolOrNull(data['flagsKnown']),
    hintsUsed: _nonNegativeInt(data['hintsUsed']) ?? 0,
    clearedAt: _dateOrNull(data['clearedAt']),
  );
}

/// Firestore payload for [streak]. `lastClearedDateId` is always written (null
/// clears it); `isOnFreeze` is display-only and never stored.
Map<String, dynamic> streakToFirestore(GameStreak streak) => {
  'current': streak.current < 0 ? 0 : streak.current,
  'longest': streak.longest < 0 ? 0 : streak.longest,
  'lastClearedDateId': streak.lastClearedDateId,
  'freezeAvailable': streak.freezeAvailable,
  'updatedAt': FieldValue.serverTimestamp(),
};

/// Parses a streak doc for [gameId]. Returns null when [data] is null.
GameStreak? streakFromFirestore(
  Map<String, dynamic>? data, {
  required String gameId,
}) {
  if (data == null) return null;
  final last = data['lastClearedDateId'];
  return GameStreak(
    gameId: gameId,
    current: _nonNegativeInt(data['current']) ?? 0,
    longest: _nonNegativeInt(data['longest']) ?? 0,
    lastClearedDateId: last is String && _dateIdPattern.hasMatch(last)
        ? last
        : null,
    freezeAvailable: _boolOrNull(data['freezeAvailable']) ?? true,
  );
}

/// Data of a fetched progress doc that may stand for the server state.
///
/// A snapshot with local writes the server has not acknowledged yet (queued
/// offline, or a slow ack) already shows them (latency compensation); if the
/// sync compared against it, it could record a "pushed" marker for a write
/// the server later rejects. Throws instead, so the item is retried.
Map<String, dynamic>? confirmedSnapshotData(
  Map<String, dynamic>? data, {
  required bool hasPendingWrites,
}) {
  if (hasPendingWrites) {
    throw const Failure('Progress has unconfirmed local writes.');
  }
  return data;
}

int? _nonNegativeInt(Object? value) {
  if (value is int) return value >= 0 ? value : null;
  if (value is num && value.isFinite && value == value.truncate()) {
    return value >= 0 ? value.toInt() : null;
  }
  return null;
}

bool? _boolOrNull(Object? value) => value is bool ? value : null;

DateTime? _dateOrNull(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

class ProgressRemoteRepositoryImpl implements ProgressRemoteRepository {
  ProgressRemoteRepositoryImpl({
    this._firestore,
    this.timeout = const Duration(seconds: 10),
  });

  final FirebaseFirestore? _firestore;

  /// Bounds each call. Offline, a merge write stays queued by Firestore
  /// persistence but its future only completes on server ack; timing out
  /// reports a failure (so the caller retries later) instead of hanging.
  final Duration timeout;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  static const _unavailable = Failure('Firebase is unavailable.');

  void _assertIds({required String uid, required String gameId}) {
    if (uid.isEmpty) throw const Failure('Sign in required to sync progress.');
    if (!_syncedGameIds.contains(gameId)) {
      throw Failure('Unsupported progress game: $gameId');
    }
  }

  void _assertPlayId(String playId) {
    if (!_playIdPattern.hasMatch(playId)) {
      throw Failure('Invalid progress period: $playId');
    }
  }

  DocumentReference<Map<String, dynamic>> _dayRef(
    FirebaseFirestore db,
    String uid,
    String gameId,
    String playId,
  ) => db
      .collection('users')
      .doc(uid)
      .collection(progressCollections().gameDays)
      .doc(gameDayDocId(gameId, playId));

  DocumentReference<Map<String, dynamic>> _streakRef(
    FirebaseFirestore db,
    String uid,
    String gameId,
  ) => db
      .collection('users')
      .doc(uid)
      .collection(progressCollections().gameStreaks)
      .doc(gameId);

  /// Null when Firebase is not ready or the doc does not exist.
  @override
  Future<GameDayRecord?> fetchDay({
    required String uid,
    required String gameId,
    required String playId,
  }) async {
    _assertIds(uid: uid, gameId: gameId);
    _assertPlayId(playId);
    final db = _db;
    if (db == null) return null;
    try {
      final snap = await _dayRef(
        db,
        uid,
        gameId,
        playId,
      ).get().timeout(timeout);
      return gameDayFromFirestore(
        confirmedSnapshotData(
          snap.data(),
          hasPendingWrites: snap.metadata.hasPendingWrites,
        ),
        gameId: gameId,
        playId: playId,
      );
    } catch (e, st) {
      debugPrint('Progress fetchDay failed: $e');
      debugPrint('$st');
      throw Failure('Could not load progress.', cause: e);
    }
  }

  /// Merge write (not a transaction) so it queues while offline.
  @override
  Future<void> saveDay({
    required String uid,
    required GameDayRecord record,
  }) async {
    _assertIds(uid: uid, gameId: record.gameId);
    _assertPlayId(record.playId);
    final db = _db;
    if (db == null) throw _unavailable;
    try {
      await _dayRef(db, uid, record.gameId, record.playId)
          .set(gameDayToFirestore(record), SetOptions(merge: true))
          .timeout(timeout);
    } catch (e, st) {
      debugPrint('Progress saveDay failed: $e');
      debugPrint('$st');
      throw Failure('Could not save progress.', cause: e);
    }
  }

  /// Null when Firebase is not ready or the doc does not exist.
  @override
  Future<GameStreak?> fetchStreak({
    required String uid,
    required String gameId,
  }) async {
    _assertIds(uid: uid, gameId: gameId);
    final db = _db;
    if (db == null) return null;
    try {
      final snap = await _streakRef(db, uid, gameId).get().timeout(timeout);
      return streakFromFirestore(
        confirmedSnapshotData(
          snap.data(),
          hasPendingWrites: snap.metadata.hasPendingWrites,
        ),
        gameId: gameId,
      );
    } catch (e, st) {
      debugPrint('Progress fetchStreak failed: $e');
      debugPrint('$st');
      throw Failure('Could not load progress.', cause: e);
    }
  }

  /// Merge write (not a transaction) so it queues while offline.
  @override
  Future<void> saveStreak({
    required String uid,
    required GameStreak streak,
  }) async {
    _assertIds(uid: uid, gameId: streak.gameId);
    final db = _db;
    if (db == null) throw _unavailable;
    try {
      await _streakRef(db, uid, streak.gameId)
          .set(streakToFirestore(streak), SetOptions(merge: true))
          .timeout(timeout);
    } catch (e, st) {
      debugPrint('Progress saveStreak failed: $e');
      debugPrint('$st');
      throw Failure('Could not save progress.', cause: e);
    }
  }
}
