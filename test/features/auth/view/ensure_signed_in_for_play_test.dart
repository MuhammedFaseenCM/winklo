import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/sync_progress.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/auth/view/ensure_signed_in_for_play.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockSyncProgress extends Mock implements SyncProgress {}

const _user = AppUser(uid: 'u1', displayName: 'A');

void main() {
  late _MockAuthRepository auth;
  late StreamController<AppUser?> users;
  late _MockSyncProgress sync;
  late AuthCubit authCubit;
  bool? result;
  late List<bool> results;

  setUp(() {
    auth = _MockAuthRepository();
    users = StreamController<AppUser?>.broadcast();
    sync = _MockSyncProgress();
    result = null;
    results = [];
    when(() => auth.authStateChanges()).thenAnswer((_) => users.stream);
  });

  tearDown(() async {
    await authCubit.close();
    await users.close();
  });

  Future<void> pumpHost(WidgetTester tester) async {
    authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await tester.pumpWidget(
      RepositoryProvider<SyncProgress>.value(
        value: sync,
        child: BlocProvider.value(
          value: authCubit,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await ensureSignedInForPlay(context);
                    results.add(result!);
                  },
                  child: const Text('play'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> signInThroughSheet(WidgetTester tester) async {
    await tester.tap(find.text('play'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
    when(() => auth.currentUser).thenReturn(_user);
    users.add(_user);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('already signed in returns true without syncing', (tester) async {
    when(() => auth.currentUser).thenReturn(_user);
    await pumpHost(tester);
    users.add(_user);
    await tester.pump();

    await tester.tap(find.text('play'));
    await tester.pump();

    expect(result, isTrue);
    verifyNever(() => sync(pull: any(named: 'pull')));
  });

  testWidgets('fresh sign-in awaits a full sync before returning', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(null);
    final pending = Completer<SyncProgressResult>();
    when(
      () => sync(pull: any(named: 'pull')),
    ).thenAnswer((_) => pending.future);
    await pumpHost(tester);

    await signInThroughSheet(tester);

    verify(() => sync(pull: true)).called(1);
    expect(result, isNull);

    pending.complete(const SyncProgressResult(localChanged: true));
    await tester.pump();
    expect(result, isTrue);
  });

  testWidgets('a second tap while the sync is pending cannot open play', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(null);
    final pending = Completer<SyncProgressResult>();
    when(
      () => sync(pull: any(named: 'pull')),
    ).thenAnswer((_) => pending.future);
    await pumpHost(tester);

    await signInThroughSheet(tester);
    expect(results, isEmpty);

    // Signed in now, but the first call has not returned yet.
    await tester.tap(find.text('play'));
    await tester.pump();
    expect(results, [false]);

    pending.complete(const SyncProgressResult());
    await tester.pump();
    expect(results, [false, true]);

    // Once settled, a tap goes straight through again.
    await tester.tap(find.text('play'));
    await tester.pump();
    expect(results, [false, true, true]);
    verify(() => sync(pull: true)).called(1);
  });

  testWidgets('sync slower than 3 s does not block play', (tester) async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => sync(pull: any(named: 'pull')),
    ).thenAnswer((_) => Completer<SyncProgressResult>().future);
    await pumpHost(tester);

    await signInThroughSheet(tester);
    expect(result, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(result, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(result, isTrue);
  });

  testWidgets('sync error is ignored', (tester) async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => sync(pull: any(named: 'pull')),
    ).thenAnswer((_) async => throw StateError('offline'));
    await pumpHost(tester);

    await signInThroughSheet(tester);

    expect(result, isTrue);
  });

  testWidgets('cancelled sign-in returns false without syncing', (
    tester,
  ) async {
    when(() => auth.currentUser).thenReturn(null);
    await pumpHost(tester);

    await tester.tap(find.text('play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.signInCancel));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => sync(pull: any(named: 'pull')));
  });
}
