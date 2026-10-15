import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/leaderboard_period.dart';
import '../../domain/entities/leaderboard_proof.dart';
import '../../domain/failures.dart';
import '../../domain/game_ids.dart';
import '../../domain/iso_week.dart';
import '../../domain/leaderboard_limits.dart';
import '../../domain/leaderboard_ranking.dart';
import '../../domain/league_code.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../clients/leaderboard/leaderboard_submit_client.dart';
import '../leaderboard_identity.dart';
import '../leaderboard_root.dart';

const _allowedGameIds = {GameIds.zip, GameIds.pathWords, GameIds.sudoku};

/// Daily board key `yyyy-MM-dd`.
final _dayIdPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Every key [leaderboardImprovePayload] may write on a leaderboard doc.
///
/// Must match the rules' `validLeaderboardKeys` whitelist exactly (the
/// `currentStreak` incident: a key written here but missing there rejects the
/// whole write). `test/firestore/rules_key_whitelist_test.dart` pins both.
const leaderboardFirestoreKeys = {
  'timeSeconds',
  'updatedAt',
  'displayName',
  'photoUrl',
  'avatarId',
  'usedHints',
  'hadMistakes',
  'currentStreak',
};

/// Every field on a weekly entry
/// (`leaderboards/{gameId}/weekly/{weekId}/entries/{uid}`). Only the
/// leaderboard Worker writes them (`WEEKLY_FIELDS` in
/// workers/leaderboard/src/limits.ts); `test/firestore` pins both.
const weeklyLeaderboardFields = {
  'displayName',
  'photoUrl',
  'avatarId',
  'days',
  'daysCleared',
  'totalSeconds',
  'updatedAt',
};

/// Merge payload for one improve-only leaderboard write: `currentStreak`
/// always; time + clean-run flags only when [timeImproved]; identity when
/// known.
Map<String, dynamic> leaderboardImprovePayload({
  required bool timeImproved,
  required int timeSeconds,
  required bool usedHints,
  required bool hadMistakes,
  required int currentStreak,
  ({String displayName, String? photoUrl, String? avatarId})? identity,
}) {
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
  return payload;
}

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

/// Maps weekly rows (already ordered by days cleared, then total time, then
/// `updatedAt`) to ranked entries whose [LeaderboardEntry.timeSeconds] is the
/// week's total. Equal days and totals share a dense rank.
List<LeaderboardEntry> mapWeeklyLeaderboardRows(
  Iterable<({String id, Map<String, dynamic> data})> rows,
) {
  final entries = <LeaderboardEntry>[];
  var rank = 0;
  (int, int)? previous;
  for (final row in rows) {
    final data = row.data;
    final days = data['daysCleared'];
    final total = data['totalSeconds'];
    if (days is! int || days <= 0 || total is! int || total <= 0) continue;
    final updatedAtRaw = data['updatedAt'];
    final name = data['displayName'];
    final photo = data['photoUrl'];
    final avatar = data['avatarId'];
    if (previous != (days, total)) rank += 1;
    previous = (days, total);
    entries.add(
      LeaderboardEntry(
        uid: row.id,
        displayName: name is String && name.trim().isNotEmpty
            ? name.trim()
            : 'Player',
        photoUrl: photo is String && photo.isNotEmpty ? photo : null,
        avatarId: avatar is String && avatar.isNotEmpty ? avatar : null,
        timeSeconds: total,
        updatedAt: updatedAtRaw is Timestamp
            ? updatedAtRaw.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        rank: rank,
        daysCleared: days,
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
  return (
    displayName: leaderboardDisplayName(displayName),
    photoUrl: leaderboardPhotoUrl(photoUrl),
    avatarId: leaderboardAvatarId(avatar is String ? avatar : null),
  );
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

/// The leaderboard Worker's submit body (see workers/leaderboard/src/submit.ts).
///
/// A null [identity] (the profile couldn't be read) sends no name, so the
/// Worker keeps the stored one.
Map<String, Object?> leaderboardSubmitBody({
  required String gameId,
  required String dayId,
  required int timeSeconds,
  required bool usedHints,
  required bool hadMistakes,
  required int currentStreak,
  required ({String displayName, String? photoUrl, String? avatarId})? identity,
  required LeaderboardProof proof,
}) => {
  'gameId': gameId,
  'dayId': dayId,
  'timeSeconds': timeSeconds,
  'usedHints': usedHints,
  'hadMistakes': hadMistakes,
  'currentStreak': currentStreak,
  'displayName': identity?.displayName,
  'photoUrl': identity?.photoUrl,
  'avatarId': identity?.avatarId,
  'proof': proof.toJson(),
};

void _recordRejectedSubmit(Object error, StackTrace stack) {
  if (!FirebaseBootstrap.isReady) return;
  FirebaseCrashlytics.instance.recordError(
    error,
    stack,
    fatal: false,
    reason: 'leaderboard_submit_rejected',
  );
}

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  /// [submitClient] posts clears to the leaderboard Worker (release builds
  /// only); without it every clear is written directly. [isDebugMode] and
  /// [now] are for tests; [reportRejected] records a refused clear
  /// (Crashlytics, as a non-fatal, by default).
  LeaderboardRepositoryImpl({
    this._firestore,
    this._auth,
    this._submitClient,
    this._isDebugMode,
    DateTime Function()? now,
    void Function(Object error, StackTrace stack)? reportRejected,
  }) : _now = now ?? DateTime.now,
       _reportRejected = reportRejected ?? _recordRejectedSubmit;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final LeaderboardSubmitClient? _submitClient;
  final bool? _isDebugMode;
  final DateTime Function() _now;
  final void Function(Object error, StackTrace stack) _reportRejected;

  String get _root => leaderboardRootCollection(isDebugMode: _isDebugMode);

  /// Release boards: the Worker serves them and the fair-play rules guard
  /// them. Debug builds keep writing `leaderboards_debug` directly.
  bool get _isReleaseRoot =>
      _root == leaderboardRootCollection(isDebugMode: false);

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

  /// Throws when [expectedUid] is set and is no longer the signed-in account.
  void _assertExpectedUser(FirebaseAuth? auth, String? expectedUid) {
    if (expectedUid == null) return;
    if (auth?.currentUser?.uid != expectedUid) {
      throw const Failure('Signed-in account changed; leaderboard skipped.');
    }
  }

  CollectionReference<Map<String, dynamic>> _boardCollection({
    required FirebaseFirestore db,
    required String gameId,
    required LeaderboardPeriod period,
    required String? dayId,
  }) {
    final gameRef = db.collection(_root).doc(gameId);
    final day = dayId ?? leaderboardDayId();
    switch (period) {
      case LeaderboardPeriod.allTime:
        return gameRef.collection('all_time');
      case LeaderboardPeriod.daily:
        return gameRef.collection('daily').doc(day).collection('entries');
      case LeaderboardPeriod.weekly:
        return gameRef
            .collection('weekly')
            .doc(isoWeekIdForDayId(day))
            .collection('entries');
    }
  }

  List<LeaderboardEntry> _mapRows(
    LeaderboardPeriod period,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final rows = snap.docs.map((d) => (id: d.id, data: d.data()));
    return period == LeaderboardPeriod.weekly
        ? mapWeeklyLeaderboardRows(rows)
        : mapLeaderboardRows(rows);
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
    // Only the Worker writes weekly totals, and only on the release boards.
    if (period == LeaderboardPeriod.weekly && !_isReleaseRoot) {
      return Stream.value(const []);
    }

    // Daily path uses a subcollection under the day doc so queries stay flat.
    final collection = _boardCollection(
      db: db,
      gameId: gameId,
      period: period,
      dayId: dayId,
    );

    final Query<Map<String, dynamic>> ordered =
        period == LeaderboardPeriod.weekly
        ? collection
              .orderBy('daysCleared', descending: true)
              .orderBy('totalSeconds')
              .orderBy('updatedAt')
        : collection.orderBy('timeSeconds').orderBy('updatedAt');

    return ordered.limit(50).snapshots().map((snap) => _mapRows(period, snap));
  }

  @override
  Stream<List<LeaderboardEntry>> watchMembersBoard({
    required String gameId,
    required LeaderboardPeriod period,
    required List<String> memberUids,
    String? dayId,
  }) {
    _assertGameId(gameId);
    final db = _db;
    if (db == null) {
      return Stream.error(const Failure('Firebase is unavailable.'));
    }
    final uids = memberUids.toSet().take(leaguesMaxMembers).toList();
    if (uids.isEmpty ||
        (period == LeaderboardPeriod.weekly && !_isReleaseRoot)) {
      return Stream.value(const []);
    }
    // A league has at most 30 members, the most `whereIn` takes; the board is
    // ranked here with the server boards' rules.
    return _boardCollection(
          db: db,
          gameId: gameId,
          period: period,
          dayId: dayId,
        )
        .where(FieldPath.documentId, whereIn: uids)
        .snapshots()
        .map((snap) => rankLeaderboardEntries(_mapRows(period, snap), period));
  }

  @override
  Future<void> submitBestTime({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
    String? dayId,
    String? expectedUid,
    LeaderboardProof? proof,
  }) async {
    _assertGameId(gameId);
    if (timeSeconds <= 0) {
      throw const Failure('Invalid time for leaderboard.');
    }
    if (dayId != null && !_dayIdPattern.hasMatch(dayId)) {
      throw Failure('Invalid leaderboard day: $dayId');
    }
    final boardDayId = dayId ?? leaderboardDayId();
    // The rules and the Worker refuse these, so there is nothing to post.
    if (_isReleaseRoot &&
        (!leaderboardAcceptsTime(gameId, timeSeconds) ||
            !leaderboardDayIsLive(boardDayId, _now()))) {
      return;
    }

    final db = _db;
    final auth = _firebaseAuth;
    final user = auth?.currentUser;
    if (db == null || user == null) {
      throw const Failure('Sign in required to join the leaderboard.');
    }
    _assertExpectedUser(auth, expectedUid);

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
    // The account may have switched during the profile read.
    _assertExpectedUser(auth, expectedUid);

    final client = _submitClient;
    final viaWorker = _isReleaseRoot && client != null && proof != null;
    if (viaWorker) {
      final posted = await _postToWorker(
        client,
        user,
        body: leaderboardSubmitBody(
          gameId: gameId,
          dayId: boardDayId,
          timeSeconds: timeSeconds,
          usedHints: usedHints,
          hadMistakes: hadMistakes,
          currentStreak: currentStreak,
          identity: identity,
          proof: proof,
        ),
      );
      if (posted) return;
      // Unreachable or failing: write directly so the time isn't lost while
      // direct writes are still allowed (fair-play phase 1).
      _assertExpectedUser(auth, expectedUid);
    }

    final root = _root;
    final allTimeRef = db
        .collection(root)
        .doc(gameId)
        .collection('all_time')
        .doc(user.uid);
    final dailyRef = db
        .collection(root)
        .doc(gameId)
        .collection('daily')
        .doc(boardDayId)
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
      if (e is FirebaseException && e.code == 'permission-denied') {
        _directWriteDenied(e, retryViaWorker: viaWorker);
      }
      debugPrint('Leaderboard submit failed: $e');
      debugPrint('$st');
      throw Failure('Could not sync leaderboard.', cause: e);
    }
  }

  /// Fair-play phase 2: the rules take no direct writes. A proven clear goes
  /// to the Worker again on the next sync, quietly; one without a proof never
  /// will be accepted, so it's final, and not an error to report.
  Never _directWriteDenied(Object error, {required bool retryViaWorker}) {
    debugPrint('Leaderboard direct write denied: $error');
    if (retryViaWorker) {
      throw Failure(
        'Could not sync leaderboard.',
        cause: error,
        reportable: false,
      );
    }
    throw const LeaderboardSubmitRefused(
      LeaderboardSubmitRefused.permissionDenied,
    );
  }

  /// True once the Worker took the clear; false when it couldn't be reached
  /// (the caller writes directly). Throws [LeaderboardSubmitRefused] when it
  /// refused the clear.
  ///
  /// A refused token is tried once more with a fresh one (the cached token
  /// can be stale when the phone's clock is off); if the Worker still won't
  /// take it, the clear is written directly rather than lost.
  Future<bool> _postToWorker(
    LeaderboardSubmitClient client,
    User user, {
    required Map<String, Object?> body,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final String idToken;
      try {
        final token = await user.getIdToken(attempt > 0);
        if (token == null || token.isEmpty) return false;
        idToken = token;
      } catch (e) {
        debugPrint('Leaderboard ID token failed: $e');
        return false;
      }
      try {
        await client.submit(idToken: idToken, body: body);
        return true;
      } on LeaderboardSubmitRejected catch (e, st) {
        if (e.code == 'unauthorized') {
          if (attempt == 0) continue;
          _reportRejected(e, st);
          return false;
        }
        _reportRejected(e, st);
        throw LeaderboardSubmitRefused(e.code);
      } on LeaderboardSubmitUnavailable catch (e) {
        debugPrint('Leaderboard Worker unavailable, writing directly: $e');
        return false;
      }
    }
    return false;
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

      final payload = leaderboardImprovePayload(
        timeImproved: timeImproved,
        timeSeconds: timeSeconds,
        usedHints: usedHints,
        hadMistakes: hadMistakes,
        currentStreak: currentStreak,
        identity: identity,
      );
      tx.set(ref, payload, SetOptions(merge: true));
    });
  }
}
