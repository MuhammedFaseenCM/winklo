import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/core/router/safe_back_button_dispatcher.dart';

void main() {
  testWidgets('didPopRoute is safe once the first route has matched', (
    tester,
  ) async {
    late final GoRouter router;
    final dispatcher = SafeGoRouterBackButtonDispatcher(() => router);
    router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const Text('home'))],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationProvider: router.routeInformationProvider,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        backButtonDispatcher: dispatcher,
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches, isNotEmpty);
    // Home root cannot pop — dispatcher should report unhandled, not throw.
    expect(await dispatcher.didPopRoute(), isFalse);
  });

  testWidgets('back from a lone page goes Home instead of closing the app', (
    tester,
  ) async {
    // A game opened from an App Link, a notification or the home-screen
    // widget is the only page on the stack.
    late final GoRouter router;
    final dispatcher = SafeGoRouterBackButtonDispatcher(() => router);
    router = GoRouter(
      initialLocation: '/zip',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/zip', builder: (_, _) => const Text('zip')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routeInformationProvider: router.routeInformationProvider,
        routeInformationParser: router.routeInformationParser,
        routerDelegate: router.routerDelegate,
        backButtonDispatcher: dispatcher,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('zip'), findsOneWidget);

    expect(await dispatcher.didPopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(await dispatcher.didPopRoute(), isFalse);
  });
}
