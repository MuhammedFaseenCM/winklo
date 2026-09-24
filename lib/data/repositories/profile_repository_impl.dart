import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/leaderboard_period.dart';
import '../../domain/failures.dart';
import '../../domain/game_ids.dart';
import '../../domain/repositories/profile_repository.dart';

const _profileUnavailable = Failure(
  'Firebase is unavailable. Try again later.',
);

/// Identity fields copied onto existing leaderboard docs.
/// Omits `updatedAt` so tie-break order stays on the score submit time.
Map<String, dynamic> leaderboardIdentityPatch(AppUser user) => {
  'displayName': user.displayName,
  'photoUrl': user.photoUrl,
  'avatarId': user.avatarId,
};

/// Maps a `users/{uid}` document. Returns null when [data] is null.
AppUser? mapUserProfile(String uid, Map<String, dynamic>? data) {
  if (data == null) return null;
  final name = data['displayName'];
  final photo = data['photoUrl'];
  final avatar = data['avatarId'];
  return AppUser(
    uid: uid,
    displayName: name is String && name.trim().isNotEmpty
        ? name.trim()
        : 'Player',
    photoUrl: photo is String && photo.isNotEmpty ? photo : null,
    avatarId: avatar is String && avatar.isNotEmpty ? avatar : null,
  );
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({this._firestore, this._auth, this._storage});

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final FirebaseStorage? _storage;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  FirebaseAuth? get _firebaseAuth {
    if (!FirebaseBootstrap.isReady) return null;
    return _auth ?? FirebaseAuth.instance;
  }

  FirebaseStorage? get _bucket {
    if (!FirebaseBootstrap.isReady) return null;
    return _storage ?? FirebaseStorage.instance;
  }

  FirebaseFirestore _requireDb() {
    final db = _db;
    if (db == null) throw _profileUnavailable;
    return db;
  }

  User _requireAuthUser() {
    final user = _firebaseAuth?.currentUser;
    if (user == null) {
      throw const Failure('Sign in required.');
    }
    return user;
  }

  @override
  Stream<AppUser?> watchProfile(String uid) {
    final db = _db;
    if (db == null) return Stream.error(_profileUnavailable);
    return db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return mapUserProfile(uid, snap.data());
    });
  }

  @override
  Future<AppUser?> getProfile(String uid) async {
    final db = _requireDb();
    try {
      final snap = await db.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      return mapUserProfile(uid, snap.data());
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Could not load profile.', cause: e);
    }
  }

  @override
  Future<AppUser> updateDisplayName(String displayName) async {
    final db = _requireDb();
    final authUser = _requireAuthUser();
    try {
      await db.collection('users').doc(authUser.uid).set({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await authUser.updateDisplayName(displayName);
      final profile = await _loadProfile(db, authUser.uid);
      await _denormalizeLeaderboards(db, profile);
      return profile;
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Could not update profile.', cause: e);
    }
  }

  @override
  Future<AppUser> updateAvatarPreset(String avatarId) async {
    final db = _requireDb();
    final authUser = _requireAuthUser();
    try {
      await db.collection('users').doc(authUser.uid).set({
        'avatarId': avatarId,
        'photoUrl': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _clearAuthPhoto(authUser);
      final profile = await _loadProfile(db, authUser.uid);
      await _denormalizeLeaderboards(db, profile);
      return profile;
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Could not update profile.', cause: e);
    }
  }

  @override
  Future<AppUser> updateAvatarPhoto(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final db = _requireDb();
    final authUser = _requireAuthUser();
    final storage = _bucket;
    if (storage == null) throw _profileUnavailable;
    try {
      final ref = storage.ref().child('avatars/${authUser.uid}.jpg');
      await ref.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: contentType),
      );
      final url = await ref.getDownloadURL();
      await db.collection('users').doc(authUser.uid).set({
        'photoUrl': url,
        'avatarId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await authUser.updatePhotoURL(url);
      final profile = await _loadProfile(db, authUser.uid);
      await _denormalizeLeaderboards(db, profile);
      return profile;
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Could not update profile.', cause: e);
    }
  }

  Future<void> _clearAuthPhoto(User user) async {
    try {
      await user.updatePhotoURL(null);
    } catch (e, st) {
      debugPrint('Could not clear auth photo URL: $e');
      debugPrint('$st');
    }
  }

  Future<AppUser> _loadProfile(FirebaseFirestore db, String uid) async {
    final snap = await db.collection('users').doc(uid).get();
    final profile = mapUserProfile(uid, snap.data());
    if (profile == null) {
      throw const Failure('Could not update profile.');
    }
    return profile;
  }

  Future<void> _denormalizeLeaderboards(
    FirebaseFirestore db,
    AppUser user,
  ) async {
    final dayId = utcLeaderboardDayId();
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final gameId in [GameIds.zip, GameIds.pathWords]) {
      final game = db.collection('leaderboards').doc(gameId);
      refs.add(game.collection('all_time').doc(user.uid));
      refs.add(
        game.collection('daily').doc(dayId).collection('entries').doc(user.uid),
      );
    }
    // Omit updatedAt so a name/avatar refresh does not reorder ties.
    final patch = leaderboardIdentityPatch(user);
    await db.runTransaction((tx) async {
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        snaps.add(await tx.get(ref));
      }
      for (var i = 0; i < refs.length; i++) {
        if (!snaps[i].exists) continue;
        tx.update(refs[i], patch);
      }
    });
  }
}
