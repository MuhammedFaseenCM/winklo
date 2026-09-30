import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/app_user.dart';

void main() {
  test('AppUser instances with the same fields are equal', () {
    // Non-const: mirrors runtime instances from auth/Firestore merges.
    final a = AppUser(
      uid: 'u1',
      displayName: 'Ada',
      photoUrl: 'https://x',
      avatarId: 'fox',
    );
    final b = AppUser(
      uid: 'u1',
      displayName: 'Ada',
      photoUrl: 'https://x',
      avatarId: 'fox',
    );

    expect(identical(a, b), isFalse);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('AppUser instances differ when a field differs', () {
    final a = AppUser(uid: 'u1', displayName: 'Ada');
    final b = AppUser(uid: 'u1', displayName: 'Bob');

    expect(a, isNot(equals(b)));
  });
}
