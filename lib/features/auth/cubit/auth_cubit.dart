import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/failures.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/clear_notification_token.dart';
import '../../../domain/usecases/sign_in_with_google.dart';
import '../../../domain/usecases/sign_out.dart';
import '../../../domain/usecases/sync_fcm_token.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this._authRepository,
    required this._signInWithGoogle,
    required this._signOut,
    this._syncFcmToken,
    this._clearNotificationToken,
  }) : super(
         _authRepository.currentUser != null
             ? AuthState(
                 status: AuthStatus.signedIn,
                 user: _authRepository.currentUser,
               )
             : const AuthState(),
       ) {
    _subscription = _authRepository.authStateChanges().listen((user) {
      if (isClosed) return;
      if (user == null) {
        emit(const AuthState(status: AuthStatus.signedOut));
        return;
      }
      // authStateChanges also re-emits on users/{uid} profile snapshots.
      // Only sync FCM when the signed-in uid changes — otherwise writing
      // fcmUpdatedAt retriggers snapshots and loops forever.
      final previousUid = state.user?.uid;
      emit(AuthState(status: AuthStatus.signedIn, user: user));
      if (previousUid != user.uid) {
        unawaited(_syncFcmToken?.call(user.uid));
      }
    });
  }

  final AuthRepository _authRepository;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;
  final SyncFcmToken? _syncFcmToken;
  final ClearNotificationToken? _clearNotificationToken;
  StreamSubscription? _subscription;

  bool get isSignedIn => state.user != null;

  Future<bool> signIn() async {
    emit(state.copyWith(status: AuthStatus.signingIn, error: null));
    try {
      final user = await _signInWithGoogle();
      if (isClosed) return false;
      emit(AuthState(status: AuthStatus.signedIn, user: user));
      unawaited(_syncFcmToken?.call(user.uid));
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
    final uid = state.user?.uid;
    // Firebase/Google sign-out first so UI can flip to signed-out immediately.
    // FCM cleanup can hang on some devices — never block sign-out on it.
    await _signOut();
    if (isClosed) return;
    emit(const AuthState(status: AuthStatus.signedOut));
    unawaited(_clearNotificationToken?.call(uid: uid));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
