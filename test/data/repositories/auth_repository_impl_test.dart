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
}
