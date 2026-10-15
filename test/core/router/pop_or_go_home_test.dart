import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/core/router/pop_or_go_home.dart';

void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Text('home')),
      GoRoute(
        path: '/zip',
        builder: (context, _) => TextButton(
          onPressed: () => popOrGoHome(context),
          child: const Text('back'),
        ),
      ),
    ],
  );

  Future<GoRouter> pump(WidgetTester tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    return router;
  }

  testWidgets('pops back to the page underneath', (tester) async {
    final router = await pump(tester);
    unawaited(router.push('/zip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('goes home when a link opened the page', (tester) async {
    final router = await pump(tester);
    // What an App Link or a notification does: nothing underneath.
    router.go('/zip');
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse);

    await tester.tap(find.text('back'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
