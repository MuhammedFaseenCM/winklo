import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/achievements/view/badges_screen.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';
import 'package:winklo/features/profile/view/profile_screen.dart';

import '../../../helpers/mock_analytics_repository.dart';
import '../../../helpers/screenshot.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockLoadHistory extends Mock implements LoadGameHistory {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

const _user = AppUser(uid: 'u1', displayName: 'Anu');

/// Zip on a 4-day run (first clear and nothing else), one Path Words clear.
GameHistory _history() => GameHistory(
  days: [
    for (var d = 12; d <= 15; d++)
      GameDayRecord(
        gameId: GameIds.zip,
        playId: '202610$d',
        timeSeconds: d == 15 ? 52 : 75,
      ),
    const GameDayRecord(
      gameId: GameIds.pathWords,
      playId: '20261015',
      timeSeconds: 140,
    ),
  ],
  streaks: const {
    GameIds.zip: GameStreak(gameId: GameIds.zip, current: 4, longest: 4),
  },
  today: DateTime(2026, 10, 15),
);

/// Profile and Badges inside the dashboard's dock shell: nothing overflows,
/// the last row clears the dock, and with `WINKLO_SCREENSHOTS=1`, PNGs in
/// build/screenshots/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) => Completer<Object?>().future,
        );
    await loadScreenshotFonts();
  });

  const boundary = Key('profile_shot');

  Future<(GoRouter, List<FlutterErrorDetails>)> pump(
    WidgetTester tester,
    Size size,
  ) async {
    final overflows = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) overflows.add(details);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(_user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(_user));
    final profile = _MockProfileRepository();
    when(
      () => profile.watchProfile(_user.uid),
    ).thenAnswer((_) => Stream<AppUser?>.value(_user));
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final load = _MockLoadHistory();
    when(
      () => load(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history());
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);

    Widget shell(Widget body) => Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: FloatingNavDock(
        selectedIndex: 3,
        onDestinationSelected: (_) {},
      ),
    );
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => shell(const ProfileScreen()),
          routes: [
            GoRoute(
              path: 'badges',
              builder: (_, _) => shell(const BadgesScreen()),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AuthRepository>.value(value: auth),
            RepositoryProvider<ProfileRepository>.value(value: profile),
            RepositoryProvider<UpdateDisplayName>.value(
              value: UpdateDisplayName(profile),
            ),
            RepositoryProvider<UpdateAvatar>.value(
              value: UpdateAvatar(profile),
            ),
            RepositoryProvider<AnalyticsRepository>.value(value: analytics),
            RepositoryProvider<LoadGameHistory>.value(value: load),
          ],
          child: BlocProvider.value(
            value: authCubit,
            child: MaterialApp.router(
              theme: buildAppTheme(),
              debugShowCheckedModeBanner: false,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return (router, overflows);
  }

  Future<void> shot(
    WidgetTester tester,
    List<FlutterErrorDetails> overflows,
    String name,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    expect(overflows, isEmpty, reason: '$name: ${overflows.firstOrNull}');
    await saveScreenshot(tester, find.byKey(boundary), name);
  }

  for (final size in const [Size(390, 800), Size(360, 640)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('Profile, $tag: badges summary, last row clear of the dock', (
      tester,
    ) async {
      final (_, overflows) = await pump(tester, size);
      expect(
        find.text(AppStrings.achievementNext('7-day Zip streak')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.achievementStreakProgress(4, 7)), findsOne);
      await shot(tester, overflows, 'profile_top_$tag');

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -3000),
      );
      await settle(tester);
      final dock = tester.getRect(find.byKey(const Key('floating_nav_dock')));
      final last = tester.getRect(find.text(AppStrings.deleteAccount));
      expect(last.bottom, lessThan(dock.top));
      await shot(tester, overflows, 'profile_end_$tag');
    });

    testWidgets('Badges, $tag', (tester) async {
      final (router, overflows) = await pump(tester, size);
      router.go('/profile/badges');
      await settle(tester);
      expect(find.text(AppStrings.achievementCurrentStreak(4)), findsOne);
      await shot(tester, overflows, 'badges_top_$tag');
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await settle(tester);
      final dock = tester.getRect(find.byKey(const Key('floating_nav_dock')));
      final last = tester.getRect(
        find.text(AppStrings.achievementFlawlessSudokusCondition),
      );
      expect(last.bottom, lessThan(dock.top));
      await shot(tester, overflows, 'badges_end_$tag');
    });
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
