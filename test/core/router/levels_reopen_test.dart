import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';

import '../../helpers/level_fixtures.dart';
import '../../helpers/mock_analytics_repository.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _Worlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      LevelCatalog([levelWorld(1, 3)]);
}

/// The real `/levels` builder: a fresh `extra` token rebuilds the map, so
/// Next level reopens a sheet even for the level it opened last time.
void main() {
  late GoRouter router;
  late StatefulNavigationShell shell;

  Future<void> pumpRouter(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    final auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return navigationShell;
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Text('home-body')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: levelsLocation, builder: buildLevelsRoute),
              ],
            ),
          ],
        ),
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsNothing);
  }

  testWidgets('Next level to the same level again reopens its sheet', (
    tester,
  ) async {
    await pumpRouter(tester);
    final a = levelId(1, 1);

    router.go(levelsOpenLocation(a), extra: Object());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
    await dismissSheet(tester);

    router.go(levelsOpenLocation(a), extra: Object());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
  });

  testWidgets('switching tabs away and back keeps the map, sheet closed', (
    tester,
  ) async {
    await pumpRouter(tester);
    router.go(levelsOpenLocation(levelId(1, 1)), extra: Object());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelPlay), findsOneWidget);
    await dismissSheet(tester);

    shell.goBranch(0);
    await tester.pumpAndSettle();
    expect(find.text('home-body'), findsOneWidget);
    shell.goBranch(1);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), levelsOpenLocation(levelId(1, 1)));
    expect(find.text(AppStrings.levelPlay), findsNothing);
  });
}
