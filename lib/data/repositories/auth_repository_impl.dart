import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/errors/client_error_reporter.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/failures.dart';
import '../../domain/repositories/auth_repository.dart';

/// Firestore fields to merge on sign-in. Omits `avatarId` so an existing
/// preset is left intact, and skips name/photo when the profile already has them.
Map<String, Object?> authProfileUpsertFields({
  required String authDisplayName,
  String? authPhotoUrl,
  Map<String, dynamic>? existing,
}) {
  final fields = <String, Object?>{};
  final existingName = existing?['displayName'];
  if (existingName is! String || existingName.trim().isEmpty) {
    fields['displayName'] = authDisplayName;
  }
  final hasPhotoKey = existing != null && existing.containsKey('photoUrl');
  if (!hasPhotoKey) {
    fields['photoUrl'] = authPhotoUrl;
  }
  return fields;
}

/// Prefers `users/{uid}` identity fields when that document is present.
AppUser mergeAuthWithProfile({
  required String uid,
  required String? authDisplayName,
  String? authPhotoUrl,
  Map<String, dynamic>? profile,
}) {
  final fallbackName = () {
    final name = authDisplayName?.trim();
    if (name == null || name.isEmpty) return 'Player';
    return name;
  }();
  if (profile == null) {
    return AppUser(uid: uid, displayName: fallbackName, photoUrl: authPhotoUrl);
  }
  final name = profile['displayName'];
  final hasName = name is String && name.trim().isNotEmpty;
  final photoUrl = profile.containsKey('photoUrl')
      ? (profile['photoUrl'] is String &&
                (profile['photoUrl'] as String).isNotEmpty
            ? profile['photoUrl'] as String
            : null)
      : authPhotoUrl;
  final avatar = profile['avatarId'];
  return AppUser(
    uid: uid,
    displayName: hasName ? (name).trim() : fallbackName,
    photoUrl: photoUrl,
    avatarId: avatar is String && avatar.isNotEmpty ? avatar : null,
  );
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    FirebaseAuth? this._auth,
    FirebaseFirestore? this._firestore,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;
  AppUser? _cachedUser;

  /// Web OAuth client (`client_type: 3` in `google-services.json`).
  /// Passed explicitly: release packaging can strip `@string/default_web_client_id`,
  /// which makes Credential Manager fail before the account picker appears.
  static const _googleServerClientId =
      '43073222004-8urlsjf12lie435qjsk8t1tk9br7onp9.apps.googleusercontent.com';

  FirebaseAuth? get _firebaseAuth {
    if (!FirebaseBootstrap.isReady) return null;
    return _auth ?? FirebaseAuth.instance;
  }

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    final name = user.displayName?.trim();
    return AppUser(
      uid: user.uid,
      displayName: (name == null || name.isEmpty) ? 'Player' : name,
      photoUrl: user.photoURL,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    final auth = _firebaseAuth;
    if (auth == null) return Stream.value(null);
    return auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        _cachedUser = null;
        return Stream<AppUser?>.value(null);
      }
      final db = _db;
      if (db == null) {
        final mapped = _mapUser(user);
        _cachedUser = mapped;
        return Stream<AppUser?>.value(mapped);
      }
      return db.collection('users').doc(user.uid).snapshots().map((snap) {
        final merged = mergeAuthWithProfile(
          uid: user.uid,
          authDisplayName: user.displayName,
          authPhotoUrl: user.photoURL,
          profile: snap.exists ? snap.data() : null,
        );
        _cachedUser = merged;
        return merged;
      });
    });
  }

  @override
  AppUser? get currentUser {
    final authUser = _firebaseAuth?.currentUser;
    if (authUser == null) return null;
    final cached = _cachedUser;
    if (cached != null && cached.uid == authUser.uid) return cached;
    return _mapUser(authUser);
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    _googleInitialized = true;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw const Failure('Firebase is unavailable. Try again later.');
    }

    try {
      await _ensureGoogleInitialized();
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const Failure('Google sign-in did not return an ID token.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await auth.signInWithCredential(credential);
      final signedIn = result.user;
      final appUser = _mapUser(signedIn);
      if (signedIn == null || appUser == null) {
        throw const Failure('Sign-in failed.');
      }
      await _upsertProfile(appUser);
      final merged = await _readMerged(signedIn);
      return merged ?? appUser;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const Failure('sign_in_cancelled');
      }
      debugPrint(
        'GoogleSignInException code=${e.code} description=${e.description}',
      );
      ClientErrorReporter.instance.reportHandled(
        code: 'google_sign_in_${e.code.name}',
        message: e.description ?? 'Google sign-in failed.',
        cause: e.toString(),
        function: 'AuthRepositoryImpl.signInWithGoogle',
      );
      throw Failure('Google sign-in failed.', cause: e);
    } on Failure catch (e) {
      if (e.message != 'sign_in_cancelled') {
        ClientErrorReporter.instance.reportHandled(
          code: 'google_sign_in_failure',
          message: e.message,
          cause: e.cause?.toString(),
          function: 'AuthRepositoryImpl.signInWithGoogle',
        );
      }
      rethrow;
    } catch (e, st) {
      debugPrint('Google sign-in unexpected error: $e\n$st');
      ClientErrorReporter.instance.reportHandled(
        code: 'google_sign_in_unexpected',
        message: e.toString(),
        cause: e.runtimeType.toString(),
        stack: st.toString(),
        function: 'AuthRepositoryImpl.signInWithGoogle',
      );
      throw Failure('Google sign-in failed.', cause: e);
    }
  }

  Future<void> _upsertProfile(AppUser user) async {
    final db = _db;
    if (db == null) return;
    try {
      final ref = db.collection('users').doc(user.uid);
      final existing = await ref.get();
      final fields = authProfileUpsertFields(
        authDisplayName: user.displayName,
        authPhotoUrl: user.photoUrl,
        existing: existing.data(),
      );
      fields['updatedAt'] = FieldValue.serverTimestamp();
      await ref.set(fields, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Auth profile upsert failed: $e');
      debugPrint('$st');
    }
  }

  Future<AppUser?> _readMerged(User user) async {
    final db = _db;
    final fallback = _mapUser(user);
    if (db == null) return fallback;
    try {
      final snap = await db.collection('users').doc(user.uid).get();
      final merged = mergeAuthWithProfile(
        uid: user.uid,
        authDisplayName: user.displayName,
        authPhotoUrl: user.photoURL,
        profile: snap.data(),
      );
      _cachedUser = merged;
      return merged;
    } catch (e, st) {
      debugPrint('Auth profile read failed: $e');
      debugPrint('$st');
      return fallback;
    }
  }

  @override
  Future<void> signOut() async {
    final auth = _firebaseAuth;
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (e, st) {
      debugPrint('Google sign-out failed: $e');
      debugPrint('$st');
    }
    if (auth != null) {
      await auth.signOut();
    }
  }
}
