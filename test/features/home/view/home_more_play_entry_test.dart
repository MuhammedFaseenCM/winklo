import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_text_scale.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/home/view/home_screen.dart';
import 'package:winklo/features/home/view/widgets/home_more_play_entry.dart';

import '../../../helpers/screenshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(loadScreenshotFonts);

  Future<void> pumpHome(WidgetTester tester, {Key? boundary}) async {
    SharedPreferences.setMockInitialValues({
      HomeScreen.permissionPromptedKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/more', builder: (_, _) => const Text('hub')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: buildRepositoryProviders(prefs: prefs),
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            theme: buildAppTheme(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) =>
                AppTextScale(child: child ?? const SizedBox.shrink()),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('Home has one More ways to play entry that opens the hub', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.byType(HomeMorePlayEntry), findsOneWidget);
    expect(find.text(AppStrings.moreWaysTitle), findsOneWidget);
    await tester.ensureVisible(find.byType(HomeMorePlayEntry));
    await tester.tap(find.byType(HomeMorePlayEntry));
    await tester.pumpAndSettle();
    expect(find.text('hub'), findsOneWidget);
  });

  testWidgets('Home with the entry fits 360x640 without overflow', (
    tester,
  ) async {
    final overflowErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflowErrors.add(details);
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    const boundary = Key('home');
    await pumpHome(tester, boundary: boundary);
    expect(overflowErrors, isEmpty);
    // The daily tiles keep their place; the entry sits under them.
    final sudoku = tester.getRect(find.text(AppStrings.playTodaysSudoku));
    final entry = tester.getRect(find.byType(HomeMorePlayEntry));
    expect(entry.top, greaterThan(sudoku.bottom));
    // Let the tiles' entrance animations finish.
    await tester.pump(const Duration(seconds: 2));
    await saveScreenshot(tester, find.byKey(boundary), 'home_360x640');
  });
}
