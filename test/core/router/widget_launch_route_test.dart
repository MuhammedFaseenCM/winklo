import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:winklo/core/router/app_router.dart';
import 'package:winklo/core/router/pop_or_go_home.dart';
import 'package:winklo/core/router/widget_launch_route.dart';
import 'package:winklo/features/auth/cubit/auth_state.dart';

void main() {
  group('widgetLaunchLocation', () {
    test('maps each game to its route', () {
      expect(widgetLaunchLocation(Uri.parse('winkloapp://play/zip')), '/zip');
      expect(
        widgetLaunchLocation(Uri.parse('winkloapp://play/path-words')),
        '/path-words',
      );
      expect(
        widgetLaunchLocation(Uri.parse('winkloapp://play/sudoku')),
        '/sudoku',
      );
    });

    test('anything else under the scheme goes home', () {
      expect(widgetLaunchLocation(Uri.parse('winkloapp://play/chess')), '/');
      expect(widgetLaunchLocation(Uri.parse('winkloapp://play')), '/');
      expect(widgetLaunchLocation(Uri.parse('winkloapp://other/zip')), '/');
      expect(
        widgetLaunchLocation(Uri.parse('winkloapp://play/zip/extra')),
        '/',
      );
    });

    test('other links are left to the router', () {
      expect(widgetLaunchLocation(Uri.parse('/zip')), isNull);
      expect(
        widgetLaunchLocation(Uri.parse('https://winklo.pages.dev/zip')),
        isNull,
      );
    });

    test('the widget provider links to exactly these games', () {
      final kotlin = File(
        'android/app/src/main/kotlin/com/winklo/faseencm/'
        'WinkloWidgetProvider.kt',
      ).readAsStringSync();
      expect(kotlin, contains('"$widgetLaunchScheme://play/\${game.route}"'));
      final routes = RegExp(
        r'route = "([a-z-]+)"',
      ).allMatches(kotlin).map((m) => m.group(1)).toSet();
      expect(routes, widgetLaunchGames.keys.toSet());
    });
  });

  group('a widget launch through the router', () {
    GoRouter buildTestRouter({required bool signedIn}) => GoRouter(
      initialLocation: '/',
      redirect: (context, state) =>
          widgetLaunchLocation(state.uri) ??
          playAuthRedirect(
            status: signedIn ? AuthStatus.signedIn : AuthStatus.signedOut,
            isSignedIn: signedIn,
            matchedLocation: state.matchedLocation,
          ),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/zip',
          builder: (context, _) => TextButton(
            onPressed: () => popOrGoHome(context),
            child: const Text('zip'),
          ),
        ),
      ],
    );

    /// A tap while the app is running: Flutter's embedding hands the new
    /// intent's URI to the router (`onNewIntent` -> `pushRouteInformation`).
    Future<GoRouter> pump(WidgetTester tester, {required bool signedIn}) async {
      final router = buildTestRouter(signedIn: signedIn);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      // The platform delivers the widget's launch intent as a deep link.
      final message = const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', {
          'location': 'winkloapp://play/zip',
          'state': null,
        }),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        message,
        (_) {},
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('opens the game when signed in', (tester) async {
      final router = await pump(tester, signedIn: true);
      expect(find.text('zip'), findsOneWidget);
      expect(router.state.uri.toString(), '/zip');
    });

    testWidgets('signed out still lands on Home', (tester) async {
      await pump(tester, signedIn: false);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a cold start from the widget opens the game', (tester) async {
      // The launch intent's URI is the platform's initial route.
      tester.platformDispatcher.defaultRouteNameTestValue =
          'winkloapp://play/zip';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
      final router = buildTestRouter(signedIn: true);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('zip'), findsOneWidget);
      expect(router.state.uri.toString(), '/zip');
    });

    test('both launches reach the router, and only through it', () {
      // Flutter's embedding reads the launch intent's data URI, whatever
      // its action, for the initial route (cold start) and on onNewIntent
      // (a tap while the app is alive; singleTop keeps the one activity).
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:launchMode="singleTop"'));
      expect(
        manifest,
        matches(
          RegExp(
            r'android:name="flutter_deeplinking_enabled"\s*'
            r'android:value="true"',
          ),
        ),
      );
      // home_widget's own channels (initiallyLaunchedFromHomeWidget,
      // widgetClicked) carry the same tap: listening to them too would open
      // the game twice.
      final dart = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) {
            final source = f.readAsStringSync();
            return source.contains('HomeWidget.widgetClicked') ||
                source.contains('HomeWidget.initiallyLaunchedFromHomeWidget');
          })
          .map((f) => f.path);
      expect(dart, isEmpty);
    });

    testWidgets('back from a launched game goes home', (tester) async {
      await pump(tester, signedIn: true);
      await tester.tap(find.text('zip'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
