import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/features/dashboard/view/dashboard_shell.dart';

void main() {
  testWidgets('shows three nav destinations', (tester) async {
    final router = GoRouter(
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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);
    expect(find.text('home-body'), findsOneWidget);

    await tester.tap(find.text(AppStrings.navProfile));
    await tester.pumpAndSettle();
    expect(find.text('profile-body'), findsOneWidget);
  });
}
