import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/clear_notification_token.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/sync_fcm_token.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/auth/cubit/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockSyncFcmToken extends Mock implements SyncFcmToken {}

class _MockClearNotificationToken extends Mock
    implements ClearNotificationToken {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Ada');

  late _MockAuthRepository auth;
  late _MockSignInWithGoogle signIn;
  late _MockSignOut signOut;
  late _MockSyncFcmToken syncFcmToken;
  late _MockClearNotificationToken clearNotificationToken;
  late StreamController<AppUser?> controller;

  setUp(() {
    auth = _MockAuthRepository();
    signIn = _MockSignInWithGoogle();
    signOut = _MockSignOut();
    syncFcmToken = _MockSyncFcmToken();
    clearNotificationToken = _MockClearNotificationToken();
    controller = StreamController<AppUser?>.broadcast();
    when(() => auth.authStateChanges()).thenAnswer((_) => controller.stream);
    when(() => syncFcmToken(any())).thenAnswer((_) async {});
    when(
      () => clearNotificationToken(uid: any(named: 'uid')),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await controller.close();
  });

  AuthCubit buildCubit({bool withSync = false, bool withClearToken = false}) =>
      AuthCubit(
        authRepository: auth,
        signInWithGoogle: signIn,
        signOut: signOut,
        syncFcmToken: withSync ? syncFcmToken : null,
        clearNotificationToken: withClearToken ? clearNotificationToken : null,
      );

  blocTest<AuthCubit, AuthState>(
    'emits signedIn when auth stream has a user',
    build: buildCubit,
    act: (cubit) => controller.add(user),
    expect: () => [const AuthState(status: AuthStatus.signedIn, user: user)],
  );

  blocTest<AuthCubit, AuthState>(
    'does not re-emit when auth stream sends an equivalent user',
    build: buildCubit,
    act: (cubit) {
      controller.add(AppUser(uid: 'u1', displayName: 'Ada'));
      controller.add(AppUser(uid: 'u1', displayName: 'Ada'));
    },
    expect: () => [
      AuthState(
        status: AuthStatus.signedIn,
        user: AppUser(uid: 'u1', displayName: 'Ada'),
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'syncs FCM token only once for the same uid across profile snapshots',
    build: () => buildCubit(withSync: true),
    act: (cubit) async {
      controller.add(const AppUser(uid: 'u1', displayName: 'Ada'));
      controller.add(const AppUser(uid: 'u1', displayName: 'Ada'));
      controller.add(
        const AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'preset_01'),
      );
      await pumpEventQueue();
    },
    expect: () => [
      const AuthState(status: AuthStatus.signedIn, user: user),
      const AuthState(
        status: AuthStatus.signedIn,
        user: AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'preset_01'),
      ),
    ],
    verify: (_) {
      verify(() => syncFcmToken('u1')).called(1);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'signIn success emits signedIn',
    build: buildCubit,
    setUp: () {
      when(() => signIn()).thenAnswer((_) async => user);
    },
    act: (cubit) => cubit.signIn(),
    expect: () => [
      const AuthState(status: AuthStatus.signingIn),
      const AuthState(status: AuthStatus.signedIn, user: user),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'signIn cancel returns to signedOut without failure',
    build: buildCubit,
    setUp: () {
      when(() => signIn()).thenThrow(const Failure('sign_in_cancelled'));
    },
    act: (cubit) => cubit.signIn(),
    expect: () => [
      const AuthState(status: AuthStatus.signingIn),
      const AuthState(status: AuthStatus.signedOut),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'signOut emits signedOut',
    build: buildCubit,
    setUp: () {
      when(() => signOut()).thenAnswer((_) async {});
    },
    seed: () => const AuthState(status: AuthStatus.signedIn, user: user),
    act: (cubit) => cubit.signOut(),
    expect: () => [const AuthState(status: AuthStatus.signedOut)],
  );

  blocTest<AuthCubit, AuthState>(
    'signOut clears FCM token while still authenticated',
    build: () => buildCubit(withClearToken: true),
    setUp: () {
      when(() => signOut()).thenAnswer((_) async {});
    },
    seed: () => const AuthState(status: AuthStatus.signedIn, user: user),
    act: (cubit) => cubit.signOut(),
    expect: () => [const AuthState(status: AuthStatus.signedOut)],
    verify: (_) {
      verifyInOrder([() => clearNotificationToken(uid: 'u1'), () => signOut()]);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'auth stream errors do not crash and keep current state',
    build: buildCubit,
    seed: () => const AuthState(status: AuthStatus.signedIn, user: user),
    act: (cubit) async {
      controller.addError(Exception('permission-denied'));
      await pumpEventQueue();
    },
    expect: () => <AuthState>[],
  );
}
