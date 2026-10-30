import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_text_scale.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/data/repositories/habit_repository_impl.dart';
import 'package:winklo/domain/entities/app_update_decision.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/logic/progress_merge.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/app_update_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/check_app_update.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/home/view/home_screen.dart';
import 'package:winklo/features/home/view/widgets/home_more_play_entry.dart';

import '../../../helpers/screenshot.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockInAppUpdates extends Mock implements InAppUpdateRepository {}

/// A policy that asks this install for a soft update.
class _SoftUpdatePolicy implements AppUpdateRepository {
  @override
  Future<AppUpdatePolicy> getPolicy() async => const AppUpdatePolicy(
    minVersion: '1.1.0',
    minBuildNumber: 19,
    forceUpdate: false,
    playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
  );

  @override
  Future<AppInstallInfo> getInstallInfo() async =>
      const AppInstallInfo(version: '1.0.0', buildNumber: 18);

  @override
  Future<bool> openStore(String storeUrl) async => true;
}

class _FakeZipLevels implements ZipLevelRepository {
  @override
  Future<ZipLevel> fetchDailyLevel(
    DateTime date, {
    Duration period = PlayPeriod.daily,
  }) async => ZipLevel(
    id: 'daily_${PlayPeriod.id(date, period)}',
    size: 8,
    numbers: {const Cell(0, 0): 1, const Cell(7, 7): 2},
    walls: const [],
  );
}

/// The busiest Home there is: a soft update, three streaks a freeze saved,
/// the Sunday recap, a perfect day and the More ways to play entry.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(loadScreenshotFonts);

  // Sunday 18 October 2026: the recap card shows this week.
  final sunday = DateTime(2026, 10, 18, 10);
  final today = PlayPeriod.id(sunday, PlayPeriod.daily);
  const user = AppUser(uid: 'test', displayName: 'Tester');
  const games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];
  const streaks = {GameIds.zip: 12, GameIds.pathWords: 5, GameIds.sudoku: 30};
  const clearSeconds = {
    GameIds.zip: 72,
    GameIds.pathWords: 95,
    GameIds.sudoku: 140,
  };

  Future<GoRouter> pumpBusyHome(
    WidgetTester tester, {
    required Size size,
    Key? boundary,
  }) async {
    SharedPreferences.setMockInitialValues({
      HomeScreen.permissionPromptedKey: true,
      for (final game in games) ...{
        'best_time_${modeKeyFor(game, today)}': clearSeconds[game]!,
        'streak_current_$game': streaks[game]!,
        'streak_longest_$game': streaks[game]!,
        'streak_last_$game': today,
      },
      // Oldest first: Sudoku's is the most recent.
      HabitRepositoryImpl.freezeSavedKey: jsonEncode([
        for (final game in games) {'gameId': game, 'days': streaks[game]},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
    final inAppUpdates = _MockInAppUpdates();
    when(
      () => inAppUpdates.hasDownloadedUpdate(),
    ).thenAnswer((_) async => false);

    GoRoute page(String path, String label) => GoRoute(
      path: path,
      builder: (_, _) => Scaffold(body: Text(label)),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => HomeScreen(now: () => sunday),
        ),
        page('/zip', 'zip-screen'),
        page('/path-words', 'path-words-screen'),
        page('/sudoku', 'sudoku-screen'),
        page(moreWaysLocation, 'more-screen'),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          ...buildRepositoryProviders(prefs: prefs),
          RepositoryProvider<CheckAppUpdate>.value(
            value: CheckAppUpdate(_SoftUpdatePolicy()),
          ),
          RepositoryProvider<InAppUpdateRepository>.value(value: inAppUpdates),
          RepositoryProvider<ZipLevelRepository>.value(value: _FakeZipLevels()),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
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
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    // Let the entrance animations finish.
    await tester.pump(const Duration(seconds: 2));
    return router;
  }

  Rect homeViewport(WidgetTester tester) =>
      tester.getRect(find.byType(Scrollable));

  /// Whether [rect] lies inside [viewport], give or take float rounding.
  bool isInside(Rect rect, Rect viewport) =>
      rect.top >= viewport.top - 0.01 && rect.bottom <= viewport.bottom + 0.01;

  void expectEverythingShows() {
    // Home has one scroll view, and everything under the header is in it.
    expect(find.byType(Scrollable), findsOneWidget);
    Finder inScrollView(Finder finder) =>
        find.descendant(of: find.byType(Scrollable), matching: finder);
    for (final text in [
      AppStrings.updateAvailableTitle,
      AppStrings.homeRecapTitle,
      AppStrings.homePerfectDayBadge,
      AppStrings.zipTitle,
      AppStrings.pathWordsTitle,
      AppStrings.sudokuTitle,
    ]) {
      expect(inScrollView(find.text(text)), findsOneWidget, reason: text);
    }
    expect(inScrollView(find.byType(HomeMorePlayEntry)), findsOneWidget);
    // One freeze notice at a time: the most recent.
    expect(find.textContaining('Your freeze saved'), findsOneWidget);
    expect(
      inScrollView(find.text(AppStrings.freezeSavedStreak(GameIds.sudoku, 30))),
      findsOneWidget,
    );
  }

  /// Scrolls [target] fully into Home's scroll view, taps it and checks it
  /// opened [opens]; then comes back to Home.
  Future<void> scrollToAndTap(
    WidgetTester tester,
    GoRouter router,
    Finder target,
    String opens,
  ) async {
    await tester.scrollUntilVisible(target, 80);
    await tester.pumpAndSettle();
    expect(isInside(tester.getRect(target), homeViewport(tester)), isTrue);

    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(opens), findsOneWidget);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(opens), findsNothing);
  }

  Future<void> expectEveryTileReachable(
    WidgetTester tester,
    GoRouter router,
  ) async {
    final results = find.text(AppStrings.result);
    expect(results, findsNWidgets(3));
    for (final (index, opens) in [
      (0, 'zip-screen'),
      (1, 'path-words-screen'),
      (2, 'sudoku-screen'),
    ]) {
      await scrollToAndTap(tester, router, results.at(index), opens);
    }
    await scrollToAndTap(
      tester,
      router,
      find.byType(HomeMorePlayEntry),
      'more-screen',
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('a busy day fits 360x640: one notice, every tile reachable', (
    tester,
  ) async {
    final router = await pumpBusyHome(tester, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expectEverythingShows();
    // The banner stays compact: the first tile's title shows unscrolled.
    final zipTitle = tester.getRect(find.text(AppStrings.zipTitle));
    expect(isInside(zipTitle, homeViewport(tester)), isTrue);

    await expectEveryTileReachable(tester, router);
  });

  testWidgets('a busy day fits 320x640: one notice, every tile reachable', (
    tester,
  ) async {
    final router = await pumpBusyHome(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expectEverythingShows();
    await expectEveryTileReachable(tester, router);
  });

  testWidgets('a busy day at 360x640, unscrolled (screenshot)', (tester) async {
    const boundary = Key('home');
    await pumpBusyHome(tester, size: const Size(360, 640), boundary: boundary);

    expect(tester.takeException(), isNull);
    expectEverythingShows();
    await saveScreenshot(tester, find.byKey(boundary), 'home_busy_360x640');
  });
}
