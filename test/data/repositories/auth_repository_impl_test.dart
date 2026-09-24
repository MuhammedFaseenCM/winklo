import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/repositories/auth_repository_impl.dart';
import 'package:winklo/domain/failures.dart';

void main() {
  test('signInWithGoogle fails soft when Firebase is not ready', () async {
    FirebaseBootstrap.isReady = false;
    final repo = AuthRepositoryImpl(auth: null, firestore: null);

    expect(repo.currentUser, isNull);
    expect(await repo.authStateChanges().first, isNull);
    await expectLater(
      repo.signInWithGoogle(),
      throwsA(
        isA<Failure>().having(
          (f) => f.message,
          'message',
          contains('unavailable'),
        ),
      ),
    );
  });

  test('authProfileUpsertFields does not write avatarId', () {
    final fields = authProfileUpsertFields(
      authDisplayName: 'Ada',
      authPhotoUrl: 'https://example.com/g.jpg',
      existing: {
        'displayName': 'Custom',
        'photoUrl': null,
        'avatarId': 'preset_02',
      },
    );
    expect(fields.containsKey('avatarId'), isFalse);
    expect(fields.containsKey('displayName'), isFalse);
    expect(fields.containsKey('photoUrl'), isFalse);
  });

  test('authProfileUpsertFields fills name and photo on first sign-in', () {
    final fields = authProfileUpsertFields(
      authDisplayName: 'Ada',
      authPhotoUrl: 'https://example.com/g.jpg',
    );
    expect(fields['displayName'], 'Ada');
    expect(fields['photoUrl'], 'https://example.com/g.jpg');
    expect(fields.containsKey('avatarId'), isFalse);
  });

  test('mergeAuthWithProfile prefers Firestore identity', () {
    final user = mergeAuthWithProfile(
      uid: 'u1',
      authDisplayName: 'Google Name',
      authPhotoUrl: 'https://example.com/g.jpg',
      profile: {
        'displayName': 'Ada',
        'photoUrl': null,
        'avatarId': 'preset_01',
      },
    );
    expect(user.displayName, 'Ada');
    expect(user.photoUrl, isNull);
    expect(user.avatarId, 'preset_01');
  });

  test('mergeAuthWithProfile falls back to auth when doc is missing', () {
    final user = mergeAuthWithProfile(
      uid: 'u1',
      authDisplayName: 'Ada',
      authPhotoUrl: 'https://example.com/g.jpg',
    );
    expect(user.displayName, 'Ada');
    expect(user.photoUrl, 'https://example.com/g.jpg');
    expect(user.avatarId, isNull);
  });
}
