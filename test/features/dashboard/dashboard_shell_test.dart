import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/features/dashboard/view/dashboard_shell.dart';
import 'package:winklo/features/home/view/widgets/home_force_update_overlay.dart';

class _MockCheckAppUpdate extends Mock implements CheckAppUpdate {}

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

void main() {
  late _MockCheckAppUpdate checkAppUpdate;
  late _MockAppUpdateRepository appUpdateRepository;

  setUp(() {
    checkAppUpdate = _MockCheckAppUpdate();
    appUpdateRepository = _MockAppUpdateRepository();
    when(
      () => checkAppUpdate(),
    ).thenAnswer((_) async => AppUpdateDecision.none);
  });

  Widget wrap(Widget child) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CheckAppUpdate>.value(value: checkAppUpdate),
        RepositoryProvider<AppUpdateRepository>.value(
          value: appUpdateRepository,
        ),
      ],
      child: child,
    );
  }

  GoRouter buildTestRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return DashboardShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Text('home-body')),
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
      ],
    );
  }

  testWidgets('shows three nav destinations', (tester) async {
    final router = buildTestRouter();

    await tester.pumpWidget(wrap(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);
    expect(find.text('home-body'), findsOneWidget);
    expect(find.byKey(const Key('floating_nav_dock')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text(AppStrings.navProfile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('profile-body'), findsOneWidget);
  });

  testWidgets('forced update hides nav and blocks tab switches', (
    tester,
  ) async {
    when(() => checkAppUpdate()).thenAnswer(
      (_) async => const AppUpdateDecision(
        status: AppUpdateStatus.forced,
        storeUrl: 'https://example.com',
      ),
    );
    final router = buildTestRouter();

    await tester.pumpWidget(wrap(MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();

    expect(find.byType(HomeForceUpdateOverlay), findsOneWidget);
    expect(find.byKey(const Key('floating_nav_dock')), findsNothing);
    expect(find.text(AppStrings.updateRequiredTitle), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsNothing);
  });
}
