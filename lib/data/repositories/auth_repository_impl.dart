import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/failures.dart';
import '../../domain/repositories/auth_repository.dart';

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
    return auth.authStateChanges().map(_mapUser);
  }

  @override
  AppUser? get currentUser => _mapUser(_firebaseAuth?.currentUser);

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize();
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
      final appUser = _mapUser(result.user);
      if (appUser == null) {
        throw const Failure('Sign-in failed.');
      }
      await _upsertProfile(appUser);
      return appUser;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const Failure('sign_in_cancelled');
      }
      throw Failure('Google sign-in failed.', cause: e);
    } on Failure {
      rethrow;
    } catch (e) {
      throw Failure('Google sign-in failed.', cause: e);
    }
  }

  Future<void> _upsertProfile(AppUser user) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'photoUrl': user.photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      debugPrint('Auth profile upsert failed: $e');
      debugPrint('$st');
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
