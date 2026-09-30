import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Returns the current user, or runs Google sign-in when signed out.
class EnsureSignedIn {
  EnsureSignedIn(this._auth);
  final AuthRepository _auth;

  Future<AppUser> call() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    return _auth.signInWithGoogle();
  }
}
