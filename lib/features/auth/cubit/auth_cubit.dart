import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/failures.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/sign_in_with_google.dart';
import '../../../domain/usecases/sign_out.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthRepository this._authRepository,
    required SignInWithGoogle this._signInWithGoogle,
    required SignOut this._signOut,
  }) : super(const AuthState()) {
    _subscription = _authRepository.authStateChanges().listen((user) {
      if (isClosed) return;
      if (user == null) {
        emit(const AuthState(status: AuthStatus.signedOut));
      } else {
        emit(AuthState(status: AuthStatus.signedIn, user: user));
      }
    });
  }

  final AuthRepository _authRepository;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;
  StreamSubscription? _subscription;

  bool get isSignedIn => state.user != null;

  Future<bool> signIn() async {
    emit(state.copyWith(status: AuthStatus.signingIn, error: null));
    try {
      final user = await _signInWithGoogle();
      if (isClosed) return false;
      emit(AuthState(status: AuthStatus.signedIn, user: user));
      return true;
    } on Failure catch (e) {
      if (isClosed) return false;
      if (e.message == 'sign_in_cancelled') {
        emit(
          AuthState(
            status: state.user == null
                ? AuthStatus.signedOut
                : AuthStatus.signedIn,
            user: state.user,
          ),
        );
        return false;
      }
      emit(
        AuthState(
          status: AuthStatus.failure,
          user: state.user,
          error: e.message,
        ),
      );
      return false;
    } catch (e) {
      if (isClosed) return false;
      emit(
        AuthState(
          status: AuthStatus.failure,
          user: state.user,
          error: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _signOut();
    if (isClosed) return;
    emit(const AuthState(status: AuthStatus.signedOut));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
