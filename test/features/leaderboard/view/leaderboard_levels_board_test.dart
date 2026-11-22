import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/router/play_mode_route.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/leaderboard_limits.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/leaderboard/view/leaderboard_screen.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_levels_note.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_podium.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLevelProgress extends Mock implements LevelProgressRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

const _user = AppUser(uid: 'me', displayName: 'Me');

LeaderboardEntry _entry(int rank, {String? uid, int stars = 0}) =>
    LeaderboardEntry(
      uid: uid ?? 'p$rank',
      displayName: 'Player $rank',
      timeSeconds: 2531,
      updatedAt: DateTime.utc(2026, 11, 18),
      rank: rank,
      stars: stars,
      levelsCleared: 40,
    );

void main() {
  late _MockAuthRepository auth;
  late _MockWatchLeaderboard watch;
  late StreamController<List<LeaderboardEntry>> board;
  late List<LeaderboardPeriod> periods;
  late List<String> games;

  setUpAll(() => registerFallbackValue(LeaderboardPeriod.daily));

  setUp(() {
    auth = _MockAuthRepository();
    watch = _MockWatchLeaderboard();
    board = StreamController<List<LeaderboardEntry>>.broadcast();
    periods = [];
    games = [];
    when(() => auth.currentUser).thenReturn(_user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(_user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      periods.add(invocation.namedArguments[#period] as LeaderboardPeriod);
      games.add(invocation.namedArguments[#gameId] as String);
      return board.stream;
    });
  });

  tearDown(() => board.close());

  Future<GoRouter> pump(
    WidgetTester tester, {
    String location = '/leaderboard',
    LevelProgressRepository? progress,
  }) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) =>
              const LeaderboardScreen(showAllTimeLeaderboard: true),
        ),
        GoRoute(
          path: '/levels',
          builder: (_, _) => const Scaffold(body: Text('levels screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          if (progress != null)
            RepositoryProvider<LevelProgressRepository>.value(value: progress),
        ],
        child: BlocProvider.value(
          value: authCubit,
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return router;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> showLevels(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
    await settle(tester);
    expect(find.byKey(const Key('leaderboard_board_levels')), findsOneWidget);
    await tester.tap(find.byKey(const Key('leaderboard_board_levels')));
    await settle(tester);
  }

  testWidgets('the board sheet offers Levels and selects it', (tester) async {
    await pump(tester);
    await showLevels(tester);

    expect(periods.last, LeaderboardPeriod.levels);
    expect(find.text(AppStrings.leaderboardBoardLevels), findsOneWidget);
  });

  testWidgets('a levels row shows stars, then levels and total time', (
    tester,
  ) async {
    await pump(tester);
    await showLevels(tester);
    board.add([
      _entry(1, stars: 120),
      _entry(2, stars: 110),
      _entry(3, stars: 100),
      _entry(4, stars: 92),
    ]);
    await tester.pumpAndSettle();

    // The podium shows stars and the detail line.
    expect(find.byType(LeaderboardPodium), findsOneWidget);
    expect(find.text('120★'), findsOneWidget);
    expect(find.text('40 levels · 42:11'), findsNWidgets(4));
    // The row below it.
    expect(find.text('92★'), findsOneWidget);
    expect(find.text('Player 4'), findsOneWidget);
    // No clean-run key or streak chips on this board.
    expect(find.text(AppStrings.leaderboardColumnTime), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^Rank 1, Player 1, 120 stars')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('92 stars')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty board offers Play levels, which opens /levels', (
    tester,
  ) async {
    final router = await pump(tester);
    await showLevels(tester);
    board.add(const []);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardLevelsEmpty), findsOneWidget);
    await tester.tap(find.text(AppStrings.leaderboardLevelsPlay));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/levels');
    expect(find.text('levels screen'), findsOneWidget);
  });

  group('a signed-in player who is not on the board', () {
    Future<void> openWithOthers(WidgetTester tester, {int? localStars}) async {
      LevelProgressRepository? progress;
      if (localStars != null) {
        final mock = _MockLevelProgress();
        when(() => mock.progress(GameIds.zip)).thenReturn(
          LevelProgress({
            'l1': LevelRecord(stars: localStars, bestSeconds: 30),
          }),
        );
        progress = mock;
      }
      await pump(tester, progress: progress);
      await showLevels(tester);
      board.add([for (var i = 1; i <= 4; i++) _entry(i, stars: 100 - i)]);
      await tester.pumpAndSettle();
    }

    testWidgets('is asked to clear a level', (tester) async {
      await openWithOthers(tester, localStars: 0);
      expect(find.byType(LeaderboardLevelsNote), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsReplay), findsNothing);
    });

    testWidgets('is asked to replay when stars are only local', (tester) async {
      await openWithOthers(tester, localStars: 2);
      expect(find.text(AppStrings.leaderboardLevelsReplay), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsNothing);
    });

    testWidgets('gets no line when the board is full (may rank below it)', (
      tester,
    ) async {
      await pump(tester);
      await showLevels(tester);
      board.add([
        for (var i = 1; i <= leaderboardDailyLimit; i++)
          _entry(i, stars: 200 - i),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardLevelsNote), findsNothing);
    });

    testWidgets('gets the line on a board one short of full', (tester) async {
      await pump(tester);
      await showLevels(tester);
      board.add([
        for (var i = 1; i < leaderboardDailyLimit; i++)
          _entry(i, stars: 200 - i),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardLevelsNote), findsOneWidget);
    });

    testWidgets('still gets the join line without a progress provider', (
      tester,
    ) async {
      await openWithOthers(tester);
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('an empty Levels board', () {
    Future<void> openEmpty(WidgetTester tester, {int localStars = 0}) async {
      final mock = _MockLevelProgress();
      when(() => mock.progress(GameIds.zip)).thenReturn(
        localStars == 0
            ? LevelProgress.empty
            : LevelProgress({
                'l1': LevelRecord(stars: localStars, bestSeconds: 30),
              }),
      );
      await pump(tester, progress: mock);
      await showLevels(tester);
      board.add(const []);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.leaderboardLevelsEmpty), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsPlay), findsOneWidget);
    }

    testWidgets('with local stars shows the replay line', (tester) async {
      await openEmpty(tester, localStars: 3);
      expect(find.text(AppStrings.leaderboardLevelsReplay), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsNothing);
    });

    testWidgets('without local stars shows the join line', (tester) async {
      await openEmpty(tester);
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsReplay), findsNothing);
    });
  });

  group('Path Words', () {
    testWidgets('/leaderboard?game=path_words&board=levels opens its Levels', (
      tester,
    ) async {
      await pump(tester, location: '/leaderboard?game=path_words&board=levels');
      await settle(tester);
      expect(games.last, GameIds.pathWords);
      expect(periods.last, LeaderboardPeriod.levels);
      expect(find.text(AppStrings.leaderboardBoardLevels), findsOneWidget);
    });

    testWidgets('offers Levels on the Board tab', (tester) async {
      final router = await pump(tester);
      router.go('/leaderboard?game=path_words');
      await settle(tester);
      await showLevels(tester);
      expect(games.last, GameIds.pathWords);
      expect(periods.last, LeaderboardPeriod.levels);
    });

    testWidgets('an empty board reads this game\'s local stars', (
      tester,
    ) async {
      final mock = _MockLevelProgress();
      when(() => mock.progress(GameIds.zip)).thenReturn(LevelProgress.empty);
      when(() => mock.progress(GameIds.pathWords)).thenReturn(
        LevelProgress({'l1': LevelRecord(stars: 2, bestSeconds: 30)}),
      );
      await pump(
        tester,
        location: '/leaderboard?game=path_words&board=levels',
        progress: mock,
      );
      board.add(const []);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.leaderboardLevelsReplay), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsNothing);
    });

    testWidgets('Zip stars do not count on the Path Words board', (
      tester,
    ) async {
      final mock = _MockLevelProgress();
      when(() => mock.progress(GameIds.zip)).thenReturn(
        LevelProgress({'l1': LevelRecord(stars: 3, bestSeconds: 30)}),
      );
      when(
        () => mock.progress(GameIds.pathWords),
      ).thenReturn(LevelProgress.empty);
      await pump(
        tester,
        location: '/leaderboard?game=path_words&board=levels',
        progress: mock,
      );
      board.add(const []);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.leaderboardLevelsJoin), findsOneWidget);
      expect(find.text(AppStrings.leaderboardLevelsReplay), findsNothing);
    });

    testWidgets('switching to Sudoku returns to the daily board', (
      tester,
    ) async {
      final router = await pump(
        tester,
        location: '/leaderboard?game=path_words&board=levels',
      );
      router.go('/leaderboard?game=sudoku');
      await settle(tester);
      expect(games.last, GameIds.sudoku);
      expect(periods.last, LeaderboardPeriod.daily);
    });
  });

  testWidgets('Levels is not offered on other games', (tester) async {
    final router = await pump(tester);
    router.go('/leaderboard?game=sudoku');
    await settle(tester);
    await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
    await settle(tester);
    expect(find.byKey(const Key('leaderboard_board_levels')), findsNothing);
  });

  testWidgets('board=levels on a game without levels does nothing', (
    tester,
  ) async {
    final router = await pump(tester);
    router.go('/leaderboard?game=sudoku&board=levels');
    await settle(tester);
    expect(periods, isNot(contains(LeaderboardPeriod.levels)));
    expect(find.text(AppStrings.leaderboardToday), findsOneWidget);
  });

  testWidgets('a player on the board gets no join line', (tester) async {
    await pump(tester);
    await showLevels(tester);
    board.add([
      _entry(1, uid: 'me', stars: 100),
      for (var i = 2; i <= 4; i++) _entry(i, stars: 100 - i),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(LeaderboardLevelsNote), findsNothing);
  });

  testWidgets('board=levels switches an alive tab to Levels once', (
    tester,
  ) async {
    final router = await pump(tester);
    expect(periods.last, LeaderboardPeriod.daily);

    router.go('/leaderboard?game=zip&board=levels');
    await settle(tester);
    expect(periods.last, LeaderboardPeriod.levels);
    expect(find.text(AppStrings.leaderboardBoardLevels), findsOneWidget);

    // A later pick in the sheet isn't undone by the same link.
    await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('leaderboard_board_weekly')));
    await settle(tester);
    expect(periods.last, LeaderboardPeriod.weekly);

    router.go('/leaderboard?game=zip&board=levels');
    await settle(tester);
    expect(periods.last, LeaderboardPeriod.weekly);
  });

  group('the star total link, with the board alive in the tab shell', () {
    late StatefulNavigationShell shell;

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final authCubit = AuthCubit(
        authRepository: auth,
        signInWithGoogle: _MockSignInWithGoogle(),
        signOut: _MockSignOut(),
      );
      addTearDown(authCubit.close);
      final router = GoRouter(
        initialLocation: levelsLocation,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, navigationShell) {
              shell = navigationShell;
              return navigationShell;
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: levelsLocation,
                    // Stands in for the Levels tab's star total.
                    builder: (context, _) => Scaffold(
                      body: TextButton(
                        onPressed: () => context.go(
                          levelsBoardLocation,
                          extra: levelsVisitToken(),
                        ),
                        child: const Text('star total'),
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/leaderboard',
                    builder: (_, _) =>
                        const LeaderboardScreen(showAllTimeLeaderboard: true),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<WatchLeaderboard>.value(value: watch),
            RepositoryProvider<AuthRepository>.value(value: auth),
          ],
          child: BlocProvider.value(
            value: authCubit,
            child: MaterialApp.router(
              theme: buildAppTheme(),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> tapStarTotal(WidgetTester tester) async {
      shell.goBranch(0);
      await settle(tester);
      await tester.tap(find.text('star total'));
      await settle(tester);
    }

    Future<void> pickWeekly(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('leaderboard_board_weekly')));
      await settle(tester);
      expect(periods.last, LeaderboardPeriod.weekly);
    }

    testWidgets('opens Levels every time, even after another pick', (
      tester,
    ) async {
      await pumpShell(tester);
      await tapStarTotal(tester);
      expect(periods.last, LeaderboardPeriod.levels);

      await pickWeekly(tester);
      await tapStarTotal(tester);
      expect(periods.last, LeaderboardPeriod.levels);
    });

    testWidgets('coming back by the nav bar keeps a later pick', (
      tester,
    ) async {
      await pumpShell(tester);
      await tapStarTotal(tester);
      await pickWeekly(tester);

      shell.goBranch(0);
      await settle(tester);
      shell.goBranch(1);
      await settle(tester);
      expect(periods.last, LeaderboardPeriod.weekly);
    });
  });
}
