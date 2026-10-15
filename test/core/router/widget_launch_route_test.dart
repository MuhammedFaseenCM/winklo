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
    Future<GoRouter> pump(WidgetTester tester, {required bool signedIn}) async {
      final router = GoRouter(
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

    testWidgets('back from a launched game goes home', (tester) async {
      await pump(tester, signedIn: true);
      await tester.tap(find.text('zip'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
