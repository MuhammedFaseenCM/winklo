import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/auth/view/sign_in_sheet.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  testWidgets('repeated signedIn emits do not pop the last shell page', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final users = StreamController<AppUser?>.broadcast();
    addTearDown(users.close);

    when(() => auth.authStateChanges()).thenAnswer((_) => users.stream);
    when(() => auth.currentUser).thenReturn(null);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(showSignInSheet(context)),
                        child: const Text('open-sign-in'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );

    await tester.tap(find.text('open-sign-in'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);

    // First emit closes the sheet; a follow-up profile-merge emit must not
    // pop the shell page underneath.
    users.add(AppUser(uid: 'u1', displayName: 'Ada'));
    await tester.pump();
    users.add(AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'fox'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('open-sign-in'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
