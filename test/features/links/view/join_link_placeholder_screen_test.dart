import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/links/view/join_link_placeholder_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/join/:code',
          builder: (_, state) =>
              JoinLinkPlaceholderScreen(code: state.pathParameters['code']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('shows the invite code', (tester) async {
    await pump(tester, '/join/abc234');

    expect(find.text(AppStrings.joinLinkTitle), findsOneWidget);
    expect(find.text(AppStrings.joinLinkCode('ABC234')), findsOneWidget);
  });

  testWidgets('leaves out a code that is not one', (tester) async {
    await pump(tester, '/join/%20%3C%3E');

    expect(find.textContaining('Invite code'), findsNothing);
  });

  testWidgets('Back home goes home', (tester) async {
    await pump(tester, '/join/ABC234');

    await tester.tap(find.text(AppStrings.backHome));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('fits a 360×640 phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, '/join/ABC234');

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.backHome), findsOneWidget);
  });
}
