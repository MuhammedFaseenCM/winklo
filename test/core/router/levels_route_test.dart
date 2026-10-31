import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/auth/cubit/auth_state.dart';

import '../../helpers/mock_analytics_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  late AuthCubit authCubit;
  late GoRouter router;

  setUp(() {
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    router = buildRouter(analytics: analytics, authCubit: authCubit);
  });

  tearDown(() {
    router.dispose();
    return authCubit.close();
  });

  test('the tabs are Home, Levels, Board and Profile, in that order', () {
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    expect(
      [
        for (final branch in shell.branches)
          (branch.routes.first as GoRoute).path,
      ],
      ['/', '/levels', '/leaderboard', '/profile'],
    );
  });

  test('/levels, with or without open=, is a route', () {
    for (final location in ['/levels', '/levels?open=zip_1_02']) {
      final match = router.configuration.findMatch(Uri.parse(location));
      expect(match.isError, isFalse, reason: location);
      expect(match.uri.path, '/levels');
    }
  });

  test('the Levels tab shows signed out (playing still needs sign-in)', () {
    expect(isPlayableLocation('/levels'), isFalse);
    expect(
      playAuthRedirect(
        status: AuthStatus.signedOut,
        isSignedIn: false,
        matchedLocation: '/levels',
      ),
      isNull,
    );
  });
}
