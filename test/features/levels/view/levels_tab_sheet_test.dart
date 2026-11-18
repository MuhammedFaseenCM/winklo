import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/core/router/auth_router_refresh.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_level_clear.dart';
import 'package:winklo/domain/usecases/sync_progress.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/auth/cubit/auth_state.dart';
import 'package:winklo/features/dashboard/view/dashboard_shell.dart';
import 'package:winklo/features/levels/view/levels_screen.dart';

import '../../../helpers/level_fixtures.dart';
import '../../../helpers/mock_analytics_repository.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockLeaderboard extends Mock implements LeaderboardRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockSyncProgress extends Mock implements SyncProgress {}

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

class _MockSubmitLevelClear extends Mock implements SubmitLevelClear {}

class _Worlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      LevelCatalog([levelWorld(1, 3)]);
}

/// The level sheet on the real dashboard shell, over its dock.
void main() {
  late GoRouter router;
  late Completer<SyncProgressResult> syncDone;

  Future<void> pumpShell(WidgetTester tester, {bool signedIn = true}) async {
    SharedPreferences.setMockInitialValues({});
    final progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    final auth = _MockAuth();
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    when(() => auth.currentUser).thenReturn(signedIn ? user : null);
    final authStream = StreamController<AppUser?>.broadcast();
    addTearDown(authStream.close);
    when(() => auth.authStateChanges()).thenAnswer((_) => authStream.stream);
    final signInWithGoogle = _MockSignInWithGoogle();
    when(() => signInWithGoogle()).thenAnswer((_) async {
      authStream.add(user);
      return user;
    });
    syncDone = Completer<SyncProgressResult>();
    final syncProgress = _MockSyncProgress();
    final submitLevelClear = _MockSubmitLevelClear();
    when(
      () => submitLevelClear.accepted,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(
      () => syncProgress.call(pull: true),
    ).thenAnswer((_) => syncDone.future);
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: signInWithGoogle,
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);
    // Really signed out: the cubit leaves AuthStatus.unknown, so the router's
    // play redirect is live.
    if (!signedIn) authStream.add(null);
    final refresh = AuthRouterRefresh(authCubit);
    addTearDown(refresh.dispose);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final checkAppUpdate = _MockCheckAppUpdate();
    when(
      () => checkAppUpdate(),
    ).thenAnswer((_) async => AppUpdateDecision.none);

    router = GoRouter(
      initialLocation: '/levels',
      refreshListenable: refresh,
      redirect: (context, state) => playAuthRedirect(
        status: authCubit.state.status,
        isSignedIn: authCubit.isSignedIn,
        matchedLocation: state.matchedLocation,
      ),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              DashboardShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Text('home-body')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/levels',
                  builder: (_, _) => const LevelsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/leaderboard',
                  builder: (_, _) => const Text('lb-body'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (_, _) => const Text('profile-body'),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/zip', builder: (_, _) => const Text('zip screen')),
      ],
    );
    addTearDown(router.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LevelWorldRepository>.value(value: _Worlds()),
          RepositoryProvider<LevelProgressRepository>.value(value: progress),
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<LeaderboardRepository>.value(
            value: _MockLeaderboard(),
          ),
          RepositoryProvider<SubmitLevelClear>.value(value: submitLevelClear),
          RepositoryProvider<SyncProgress>.value(value: syncProgress),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<CheckAppUpdate>.value(value: checkAppUpdate),
          RepositoryProvider<AppUpdateRepository>.value(
            value: _MockAppUpdateRepository(),
          ),
        ],
        child: BlocProvider.value(
          value: authCubit,
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(AppStrings.levelNodeCurrent(1)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
    if (!signedIn) expect(authCubit.state.status, AuthStatus.signedOut);
  }

  testWidgets('the open sheet covers the dock: no dock tab can be hit', (
    tester,
  ) async {
    await pumpShell(tester);
    for (final label in [
      AppStrings.navHome,
      AppStrings.levelsTitle,
      AppStrings.navLeaderboard,
      AppStrings.navProfile,
    ]) {
      final inDock = find.descendant(
        of: find.byKey(const Key('floating_nav_dock')),
        matching: find.text(label),
      );
      expect(inDock, findsOneWidget, reason: label);
      expect(inDock.hitTestable(), findsNothing, reason: label);
    }
    // Closed, the dock works again.
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsNothing);
    await tester.tap(find.text(AppStrings.navHome));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.text('home-body'), findsOneWidget);
  });

  testWidgets('Play closes the sheet and opens the level', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text(AppStrings.levelPlay));
    await tester.pumpAndSettle();
    expect(find.text('zip screen'), findsOneWidget);
    expect(router.state.uri.toString(), '/zip?mode=level&level=zip_1_01');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsNothing);
    expect(router.state.uri.path, '/levels');
  });

  testWidgets('signed out, Play asks for sign-in and stays on the map', (
    tester,
  ) async {
    await pumpShell(tester, signedIn: false);
    await tester.tap(find.text(AppStrings.levelPlay));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.playSignInTitle), findsOneWidget);
    expect(find.text('zip screen'), findsNothing);
    expect(find.text('home-body'), findsNothing);

    await tester.tap(find.text(AppStrings.signInCancel));
    await tester.pumpAndSettle();

    // Cancelled: the level sheet is still open over the map.
    expect(find.text(AppStrings.playSignInTitle), findsNothing);
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
    expect(router.state.uri.path, '/levels');
  });

  testWidgets('signed out, signing in from Play opens the level once', (
    tester,
  ) async {
    await pumpShell(tester, signedIn: false);
    await tester.tap(find.text(AppStrings.levelPlay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.signInWithGoogle));
    await tester.pumpAndSettle();

    // Signed in, the sync is pending: a second Play is a no-op.
    expect(find.text(AppStrings.playSignInTitle), findsNothing);
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
    await tester.tap(find.text(AppStrings.levelPlay));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/levels');

    syncDone.complete(const SyncProgressResult());
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/zip?mode=level&level=zip_1_01');
    expect(find.text('zip screen'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/levels');
    expect(find.text(AppStrings.levelPlay), findsNothing);
    expect(find.text(AppStrings.playSignInTitle), findsNothing);
  });

  testWidgets('a sheet dismissed while the sign-in syncs does not open the '
      'level or pop the page under it', (tester) async {
    await pumpShell(tester, signedIn: false);
    await tester.tap(find.text(AppStrings.levelPlay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.signInWithGoogle));
    await tester.pumpAndSettle();

    // Dismiss the level sheet by its barrier while the sync is pending.
    await tester.tapAt(const Offset(195, 40));
    await tester.pump(const Duration(milliseconds: 50));
    syncDone.complete(const SyncProgressResult());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.state.uri.path, '/levels');
    expect(find.text('zip screen'), findsNothing);
    expect(find.text(AppStrings.levelPlay), findsNothing);
  });
}
