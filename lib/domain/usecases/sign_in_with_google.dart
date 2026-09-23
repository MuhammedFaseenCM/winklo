import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  SignInWithGoogle(this._auth);
  final AuthRepository _auth;

  Future<AppUser> call() => _auth.signInWithGoogle();
}
