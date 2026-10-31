import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/features/dashboard/view/dashboard_shell.dart';
import 'package:winklo/features/levels/view/levels_screen.dart';

import '../../../helpers/level_fixtures.dart';
import '../../../helpers/mock_analytics_repository.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

class _Worlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      LevelCatalog([levelWorld(1, 3)]);
}

/// The level sheet on the real dashboard shell, over its dock.
void main() {
  late GoRouter router;

  Future<void> pumpShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    final auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final checkAppUpdate = _MockCheckAppUpdate();
    when(
      () => checkAppUpdate(),
    ).thenAnswer((_) async => AppUpdateDecision.none);

    router = GoRouter(
      initialLocation: '/levels',
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
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<CheckAppUpdate>.value(value: checkAppUpdate),
          RepositoryProvider<AppUpdateRepository>.value(
            value: _MockAppUpdateRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(AppStrings.levelNodeCurrent(1)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
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
}
