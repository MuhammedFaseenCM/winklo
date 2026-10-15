import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

/// The paths `winklo.pages.dev` hands to the app (spec, roadmap batch A6).
const _gamePaths = ['/zip', '/path-words', '/sudoku'];
const _appLinkPaths = [..._gamePaths, '/leaderboard', '/join/ABC234'];

void main() {
  group('routes', () {
    late AuthCubit authCubit;

    setUp(() {
      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.authStateChanges(),
      ).thenAnswer((_) => const Stream.empty());
      authCubit = AuthCubit(
        authRepository: auth,
        signInWithGoogle: _MockSignInWithGoogle(),
        signOut: _MockSignOut(),
      );
    });

    tearDown(() => authCubit.close());

    test('every App Link path has a route', () {
      final analytics = MockAnalyticsRepository();
      stubAnalytics(analytics);
      final router = buildRouter(analytics: analytics, authCubit: authCubit);
      addTearDown(router.dispose);

      for (final path in _appLinkPaths) {
        final match = router.configuration.findMatch(Uri.parse(path));
        expect(match.isError, isFalse, reason: path);
        expect(match.uri.path, path);
      }
    });

    test('an invite link passes its code', () {
      final analytics = MockAnalyticsRepository();
      stubAnalytics(analytics);
      final router = buildRouter(analytics: analytics, authCubit: authCubit);
      addTearDown(router.dispose);

      final match = router.configuration.findMatch(Uri.parse('/join/ABC234'));

      expect(match.pathParameters['code'], 'ABC234');
    });
  });

  test('signed-out players opening a game link go home', () {
    for (final path in _gamePaths) {
      expect(
        playAuthRedirect(
          status: AuthStatus.signedOut,
          isSignedIn: false,
          matchedLocation: path,
        ),
        '/',
        reason: path,
      );
    }
  });

  test('the manifest asks Android to verify every App Link path', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final filter = RegExp(
      r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
      dotAll: true,
    ).firstMatch(manifest);

    expect(filter, isNotNull);
    final body = filter!.group(1)!;
    expect(body, contains('android.intent.action.VIEW'));
    expect(body, contains('android.intent.category.BROWSABLE'));
    expect(body, contains('android:scheme="https"'));
    expect(body, contains('android:host="winklo.pages.dev"'));
    for (final path in [..._gamePaths, '/leaderboard']) {
      expect(body, contains('android:path="$path"'), reason: path);
    }
    expect(body, contains('android:pathPrefix="/join/"'));
  });

  test('every App Link path has a page on the site', () {
    for (final page in [..._gamePaths, '/leaderboard', '/join']) {
      final file = File('docs$page/index.html');
      expect(file.existsSync(), isTrue, reason: file.path);
      // People without the app end up on the landing page.
      expect(file.readAsStringSync(), contains('http-equiv="refresh"'));
    }
    expect(
      File('docs/_redirects').readAsStringSync(),
      contains('/join/*  /join/  200'),
    );
  });
}
