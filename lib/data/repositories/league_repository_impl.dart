import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/strings/app_strings.dart';
import '../../domain/entities/league.dart';
import '../../domain/failures.dart';
import '../../domain/game_ids.dart';
import '../../domain/league_code.dart';
import '../../domain/repositories/league_repository.dart';
import '../leaderboard_root.dart';

/// Every field on a `leagues/{leagueId}` doc; must equal the rules'
/// `validLeagueCreate` whitelist (test/firestore pins both).
const leagueFirestoreKeys = {
  'name',
  'ownerUid',
  'code',
  'memberUids',
  'createdAt',
};

/// A `leagues/{id}` doc as a [League], or null when it's malformed.
League? leagueFromDoc(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  final name = data['name'];
  final owner = data['ownerUid'];
  final code = data['code'];
  final members = data['memberUids'];
  if (name is! String || owner is! String || code is! String) return null;
  if (members is! List) return null;
  final created = data['createdAt'];
  return League(
    id: id,
    name: name,
    ownerUid: owner,
    code: code,
    memberUids: [
      for (final uid in members)
        if (uid is String) uid,
    ],
    createdAt: created is Timestamp ? created.toDate() : null,
  );
}

/// The new league doc: [ownerUid] is its owner and only member.
Map<String, Object> newLeagueData({
  required String name,
  required String ownerUid,
  required String code,
}) => {
  'name': name,
  'ownerUid': ownerUid,
  'code': code,
  'memberUids': [ownerUid],
  'createdAt': FieldValue.serverTimestamp(),
};

class _CodeTaken implements Exception {}

class LeagueRepositoryImpl implements LeagueRepository {
  LeagueRepositoryImpl({this._firestore, this._auth, Random? random})
    : _random = random ?? Random.secure();

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final Random _random;

  /// New codes to try before giving up (31^6 codes, so a clash is rare).
  static const _codeAttempts = 5;

  FirebaseFirestore _db() {
    if (!FirebaseBootstrap.isReady) {
      throw const Failure(AppStrings.serviceUnavailable);
    }
    return _firestore ?? FirebaseFirestore.instance;
  }

  String _uid() {
    final uid = FirebaseBootstrap.isReady
        ? (_auth ?? FirebaseAuth.instance).currentUser?.uid
        : null;
    if (uid == null) {
      throw const LeagueFailure(
        LeagueProblem.signedOut,
        AppStrings.leaguesSignedOut,
      );
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _leagues(FirebaseFirestore db) =>
      db.collection('leagues');

  CollectionReference<Map<String, dynamic>> _codes(FirebaseFirestore db) =>
      db.collection('league_codes');

  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure(message, cause: e);
    }
  }

  @override
  Stream<List<League>> watchMyLeagues(String uid) {
    final FirebaseFirestore db;
    try {
      db = _db();
    } on Failure catch (e) {
      return Stream.error(e);
    }
    return _leagues(db).where('memberUids', arrayContains: uid).snapshots().map(
      (snap) {
        final leagues = [
          for (final doc in snap.docs) ?leagueFromDoc(doc.id, doc.data()),
        ];
        leagues.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return leagues;
      },
    );
  }

  @override
  Stream<League?> watchLeague(String leagueId) {
    final FirebaseFirestore db;
    try {
      db = _db();
    } on Failure catch (e) {
      return Stream.error(e);
    }
    return _leagues(db)
        .doc(leagueId)
        .snapshots()
        .map(
          (snap) => snap.exists ? leagueFromDoc(snap.id, snap.data()) : null,
        );
  }

  @override
  Future<League?> findByCode(String code) =>
      _guard(AppStrings.leagueLookupFailed, () async {
        final normalized = normalizeLeagueCode(code);
        if (normalized == null) return null;
        _uid();
        final db = _db();
        final pointer = await _codes(db).doc(normalized).get();
        final leagueId = pointer.data()?['leagueId'];
        if (leagueId is! String || leagueId.isEmpty) return null;
        final snap = await _leagues(db).doc(leagueId).get();
        return snap.exists ? leagueFromDoc(snap.id, snap.data()) : null;
      });

  @override
  Future<League> create(String name) =>
      _guard(AppStrings.leagueCreateFailed, () async {
        final cleaned = cleanLeagueName(name);
        if (cleaned == null) {
          throw const Failure(AppStrings.leagueNameLength);
        }
        final uid = _uid();
        final db = _db();
        for (var attempt = 0; attempt < _codeAttempts; attempt++) {
          final code = generateLeagueCode(_random);
          final leagueRef = _leagues(db).doc();
          final codeRef = _codes(db).doc(code);
          try {
            // The rules accept the league only with its code doc in the same
            // write, and the code doc only when it's new.
            await db.runTransaction((tx) async {
              final taken = await tx.get(codeRef);
              if (taken.exists) throw _CodeTaken();
              tx.set(
                leagueRef,
                newLeagueData(name: cleaned, ownerUid: uid, code: code),
              );
              tx.set(codeRef, {'leagueId': leagueRef.id});
            });
          } on _CodeTaken {
            continue;
          }
          return League(
            id: leagueRef.id,
            name: cleaned,
            ownerUid: uid,
            code: code,
            memberUids: [uid],
          );
        }
        throw const Failure(AppStrings.leagueCreateRetry);
      });

  @override
  Future<League> join(String code) =>
      _guard(AppStrings.leagueJoinFailed, () async {
        final uid = _uid();
        final league = await findByCode(code);
        if (league == null) {
          throw const LeagueFailure(
            LeagueProblem.notFound,
            AppStrings.leagueCodeNotFound,
          );
        }
        if (league.hasMember(uid)) return league;
        final db = _db();
        final ref = _leagues(db).doc(league.id);
        // Read inside the transaction so two players can't take the last place.
        final joined = await db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final current = snap.exists
              ? leagueFromDoc(snap.id, snap.data())
              : null;
          if (current == null) {
            throw const LeagueFailure(
              LeagueProblem.notFound,
              AppStrings.leagueCodeNotFound,
            );
          }
          if (current.hasMember(uid)) return current;
          if (current.isFull) {
            throw const LeagueFailure(
              LeagueProblem.full,
              AppStrings.joinLeagueFull,
            );
          }
          tx.update(ref, {
            'memberUids': FieldValue.arrayUnion([uid]),
          });
          return League(
            id: current.id,
            name: current.name,
            ownerUid: current.ownerUid,
            code: current.code,
            memberUids: [...current.memberUids, uid],
            createdAt: current.createdAt,
          );
        });
        return joined;
      });

  @override
  Future<void> leave(String leagueId) =>
      _guard(AppStrings.leagueLeaveFailed, () async {
        final uid = _uid();
        await _leagues(_db()).doc(leagueId).update({
          'memberUids': FieldValue.arrayRemove([uid]),
        });
      });

  @override
  Future<void> removeMember(String leagueId, String memberUid) =>
      _guard(AppStrings.leagueRemoveFailed, () async {
        _uid();
        await _leagues(_db()).doc(leagueId).update({
          'memberUids': FieldValue.arrayRemove([memberUid]),
        });
      });

  @override
  Future<void> rename(String leagueId, String name) =>
      _guard(AppStrings.leagueRenameFailed, () async {
        final cleaned = cleanLeagueName(name);
        if (cleaned == null) {
          throw const Failure(AppStrings.leagueNameLength);
        }
        _uid();
        await _leagues(_db()).doc(leagueId).update({'name': cleaned});
      });

  @override
  Future<void> delete(League league) =>
      _guard(AppStrings.leagueDeleteFailed, () async {
        _uid();
        final db = _db();
        final batch = db.batch()
          ..delete(_leagues(db).doc(league.id))
          ..delete(_codes(db).doc(league.code));
        await batch.commit();
      });

  @override
  Future<Map<String, LeagueMember>> memberProfiles(List<String> uids) async {
    final ids = uids.toSet().take(leaguesMaxMembers).toList();
    if (ids.isEmpty) return const {};
    final FirebaseFirestore db;
    try {
      db = _db();
    } on Failure {
      return const {};
    }
    final members = <String, LeagueMember>{};
    // The name and photo are public only on leaderboard entries.
    for (final gameId in const [
      GameIds.zip,
      GameIds.pathWords,
      GameIds.sudoku,
    ]) {
      final missing = ids.where((id) => !members.containsKey(id)).toList();
      if (missing.isEmpty) break;
      try {
        final snap = await db
            .collection(leaderboardRootCollection())
            .doc(gameId)
            .collection('all_time')
            .where(FieldPath.documentId, whereIn: missing)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = data['displayName'];
          final photo = data['photoUrl'];
          final avatar = data['avatarId'];
          members[doc.id] = LeagueMember(
            uid: doc.id,
            displayName: name is String && name.trim().isNotEmpty
                ? name.trim()
                : AppStrings.playerFallbackName,
            photoUrl: photo is String && photo.isNotEmpty ? photo : null,
            avatarId: avatar is String && avatar.isNotEmpty ? avatar : null,
          );
        }
      } catch (_) {
        // Names are a nicety; the list still shows "Player".
      }
    }
    return members;
  }
}
