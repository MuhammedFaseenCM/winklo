import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/zip_ui.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/share_repository.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/domain/usecases/claim_new_achievements.dart';
import 'package:winklo/domain/usecases/next_uncleared_daily.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';
import 'package:winklo/features/results/view/mini_leaderboard_panel.dart';
import 'package:winklo/features/results/view/results_board_tease.dart';

import '../../helpers/mock_analytics_repository.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockNextUnclearedDaily extends Mock implements NextUnclearedDaily {}

class _MockShareRepository extends Mock implements ShareRepository {}

class _MockClaimNewAchievements extends Mock implements ClaimNewAchievements {}

/// What the daily Results actions read; the app always provides them.
List<RepositoryProvider<Object>> _actionProviders() {
  final next = _MockNextUnclearedDaily();
  when(
    () => next(
      justCleared: any(named: 'justCleared'),
      playId: any(named: 'playId'),
    ),
  ).thenReturn(null);
  final analytics = MockAnalyticsRepository();
  stubAnalytics(analytics);
  return [
    RepositoryProvider<NextUnclearedDaily>.value(value: next),
    RepositoryProvider<AnalyticsRepository>.value(value: analytics),
    RepositoryProvider<ShareRepository>.value(value: _MockShareRepository()),
  ];
}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
    registerFallbackValue(<Achievement>[]);
  });

  testWidgets('Zip clear signed-in shows celebration then mini board', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'Tester'));
    when(() => auth.authStateChanges()).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'u1', displayName: 'Tester')),
    );

    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/results',
          builder: (_, _) => const ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 12,
              improved: true,
              replayDaily: true,
              gameId: GameIds.zip,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    boardController.add(const []);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.formatPlayTime(12)), findsOneWidget);
    expect(find.text(AppStrings.resultsTimeLabel), findsOneWidget);
    expect(find.text(AppStrings.newPersonalBest), findsOneWidget);
    expect(find.byType(MiniLeaderboardPanel), findsOneWidget);
    expect(find.text(AppStrings.resultsFullBoard), findsOneWidget);
    expect(find.text(AppStrings.shareResult), findsOneWidget);
    expect(find.byTooltip(AppStrings.backHome), findsOneWidget);
    expect(find.textContaining('New puzzle in'), findsOneWidget);
    expect(find.byType(ResultsBoardTease), findsNothing);
    expect(
      find.text(AppStrings.saveTimeToBoard(AppStrings.formatPlayTime(12))),
      findsNothing,
    );
  });

  testWidgets('Path Words clear signed-in shows celebration + mini board', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'Tester'));
    when(() => auth.authStateChanges()).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'u1', displayName: 'Tester')),
    );

    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(
          path: '/results',
          builder: (_, _) => const ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 12,
              improved: false,
              gameId: GameIds.pathWords,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    boardController.add(const []);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.formatPlayTime(12)), findsOneWidget);
    expect(find.byType(MiniLeaderboardPanel), findsOneWidget);
  });

  testWidgets(
    'guest Zip clear celebrates and offers soft claim, not locked board',
    (tester) async {
      final auth = _MockAuthRepository();
      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(null));

      final router = GoRouter(
        initialLocation: '/results',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/results',
            builder: (_, _) => const ResultsScreen(
              args: ResultsArgs(
                title: 'Puzzle cleared!',
                subtitle: '',
                timeSeconds: 72,
                improved: false,
                replayDaily: true,
                currentStreak: 2,
                gameId: GameIds.zip,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AuthRepository>.value(value: auth),
            ..._actionProviders(),
          ],
          child: BlocProvider(
            create: (_) => AuthCubit(
              authRepository: auth,
              signInWithGoogle: _MockSignInWithGoogle(),
              signOut: _MockSignOut(),
            ),
            child: MaterialApp.router(
              theme: buildAppTheme(),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final timeLabel = AppStrings.formatPlayTime(72);
      expect(find.text(timeLabel), findsOneWidget);
      expect(find.text(AppStrings.resultsTimeLabel), findsOneWidget);
      expect(find.text(AppStrings.streakLabel(2)), findsOneWidget);
      expect(find.text(AppStrings.saveTimeToBoard(timeLabel)), findsOneWidget);
      expect(find.text(AppStrings.backHome), findsOneWidget);
      expect(find.byType(ResultsBoardTease), findsOneWidget);
      expect(find.text(AppStrings.resultsBoardTeaseHint), findsOneWidget);
      expect(find.text('points'), findsNothing);
      expect(find.byType(MiniLeaderboardPanel), findsNothing);
      expect(find.text(AppStrings.leaderboardSignInHint), findsNothing);
      expect(find.text(AppStrings.seeFullLeaderboard), findsNothing);

      final primary = tester.widget<ZipPrimaryButton>(
        find.byType(ZipPrimaryButton),
      );
      expect(primary.label, AppStrings.saveTimeToBoard(timeLabel));
      expect(
        find.descendant(
          of: find.byType(ZipPrimaryButton),
          matching: find.text(AppStrings.backHome),
        ),
        findsNothing,
      );

      await tester.ensureVisible(find.text(AppStrings.backHome));
      await tester.tap(find.text(AppStrings.backHome));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets('guest soft claim signs in with save copy and submits time', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final submit = _MockSubmitLeaderboardTime();
    when(
      () => submit(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
      ),
    ).thenAnswer((_) async {});

    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(null));

    const signedInUser = AppUser(uid: 'uid1', displayName: 'Tester');
    final signIn = _MockSignInWithGoogle();
    when(() => signIn()).thenAnswer((_) async => signedInUser);

    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(
          path: '/results',
          builder: (_, _) => const ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 42,
              improved: false,
              replayDaily: true,
              gameId: GameIds.zip,
            ),
          ),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) => const Text('leaderboard'),
        ),
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
          RepositoryProvider<SubmitLeaderboardTime>.value(value: submit),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: signIn,
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timeLabel = AppStrings.formatPlayTime(42);
    final saveFinder = find.text(AppStrings.saveTimeToBoard(timeLabel));
    await tester.ensureVisible(saveFinder);
    await tester.tap(saveFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.saveTimeSignInTitle), findsOneWidget);
    expect(find.text(AppStrings.saveTimeSignInBody), findsOneWidget);

    await tester.tap(find.text(AppStrings.signInWithGoogle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    verify(
      () => submit(
        gameId: GameIds.zip,
        timeSeconds: 42,
        usedHints: true,
        hadMistakes: true,
        currentStreak: 0,
      ),
    ).called(1);

    when(() => auth.currentUser).thenReturn(signedInUser);
    boardController.add([
      LeaderboardEntry(
        uid: 'uid1',
        displayName: 'Ada',
        timeSeconds: 42,
        updatedAt: DateTime.utc(2026, 9, 27),
        rank: 1,
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MiniLeaderboardPanel), findsOneWidget);
    expect(find.text(AppStrings.saveTimeToBoard(timeLabel)), findsNothing);
    expect(find.byType(ResultsBoardTease), findsNothing);
  });

  testWidgets('MiniLeaderboardPanel lists entries when signed in', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'uid1', displayName: 'Tester'));
    when(() => auth.authStateChanges()).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'uid1', displayName: 'Tester')),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(
              body: MiniLeaderboardPanel(gameId: GameIds.zip),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    boardController.add([
      LeaderboardEntry(
        uid: 'uid1',
        displayName: 'Ada',
        timeSeconds: 10,
        updatedAt: DateTime.utc(2026, 9, 24),
        rank: 1,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text(AppStrings.seeFullLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.backHome), findsOneWidget);
    expect(find.text('points'), findsNothing);
  });

  testWidgets(
    'signed-out mini board sign-in submits results time then shows board',
    (tester) async {
      final auth = _MockAuthRepository();
      final boardController =
          StreamController<List<LeaderboardEntry>>.broadcast();
      addTearDown(boardController.close);

      final watch = _MockWatchLeaderboard();
      when(
        () => watch(
          gameId: any(named: 'gameId'),
          period: any(named: 'period'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer((_) => boardController.stream);

      final submit = _MockSubmitLeaderboardTime();
      when(
        () => submit(
          gameId: any(named: 'gameId'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          currentStreak: any(named: 'currentStreak'),
        ),
      ).thenAnswer((_) async {});

      when(() => auth.currentUser).thenReturn(null);
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(null));

      const signedInUser = AppUser(uid: 'uid1', displayName: 'Tester');
      final signIn = _MockSignInWithGoogle();
      when(() => signIn()).thenAnswer((_) async => signedInUser);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<WatchLeaderboard>.value(value: watch),
            RepositoryProvider<AuthRepository>.value(value: auth),
            ..._actionProviders(),
            RepositoryProvider<SubmitLeaderboardTime>.value(value: submit),
          ],
          child: BlocProvider(
            create: (_) => AuthCubit(
              authRepository: auth,
              signInWithGoogle: signIn,
              signOut: _MockSignOut(),
            ),
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const Scaffold(
                body: MiniLeaderboardPanel(
                  gameId: GameIds.zip,
                  timeSeconds: 42,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.leaderboardSignInHint), findsOneWidget);

      await tester.tap(find.text(AppStrings.signInWithGoogle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sheet open — tap Continue with Google inside the sheet.
      expect(find.text(AppStrings.signInTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.signInWithGoogle).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => submit(
          gameId: GameIds.zip,
          timeSeconds: 42,
          usedHints: true,
          hadMistakes: true,
          currentStreak: 0,
        ),
      ).called(1);

      when(() => auth.currentUser).thenReturn(signedInUser);
      boardController.add([
        LeaderboardEntry(
          uid: 'uid1',
          displayName: 'Ada',
          timeSeconds: 42,
          updatedAt: DateTime.utc(2026, 9, 26),
          rank: 1,
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(AppStrings.leaderboardSignInHint), findsNothing);
      expect(find.text('Ada'), findsOneWidget);
    },
  );

  for (final (name, size) in const [
    ('a phone turned sideways', Size(915, 412)),
    ('a short split screen', Size(412, 480)),
  ]) {
    testWidgets('$name scrolls the whole page and still shows the time', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = _MockAuthRepository();
      const me = AppUser(uid: 'u1', displayName: 'Tester');
      when(() => auth.currentUser).thenReturn(me);
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(me));
      final watch = _MockWatchLeaderboard();
      when(
        () => watch(
          gameId: any(named: 'gameId'),
          period: any(named: 'period'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer((_) => Stream.value(const []));

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<WatchLeaderboard>.value(value: watch),
            RepositoryProvider<AuthRepository>.value(value: auth),
            ..._actionProviders(),
          ],
          child: BlocProvider(
            create: (_) => AuthCubit(
              authRepository: auth,
              signInWithGoogle: _MockSignInWithGoogle(),
              signOut: _MockSignOut(),
            ),
            child: MaterialApp(
              theme: buildAppTheme(),
              home: const ResultsScreen(
                args: ResultsArgs(
                  title: 'Puzzle cleared!',
                  subtitle: '',
                  timeSeconds: 72,
                  improved: true,
                  replayDaily: true,
                  gameId: GameIds.zip,
                  currentStreak: 6,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings.formatPlayTime(72)).hitTestable(),
        findsOneWidget,
      );
      // The board and its actions are a scroll away.
      await tester.scrollUntilVisible(
        find.text(AppStrings.shareResult),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(AppStrings.shareResult).hitTestable(), findsOneWidget);
    });
  }

  testWidgets('a typical phone shows the whole celebration, countdown '
      'included', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _MockAuthRepository();
    const me = AppUser(uid: 'u1', displayName: 'Tester');
    when(() => auth.currentUser).thenReturn(me);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(me));
    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => Stream.value(const []));
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/results',
          builder: (_, _) => ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 72,
              improved: true,
              replayDaily: true,
              gameId: GameIds.zip,
              currentStreak: 6,
              longestStreak: 14,
              day: DateTime.now(),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final countdown = find.textContaining('New puzzle in');
    final header = find.ancestor(
      of: countdown,
      matching: find.byType(SingleChildScrollView),
    );
    expect(
      tester.getRect(countdown).bottom,
      lessThanOrEqualTo(tester.getRect(header).bottom),
    );
    expect(find.text(AppStrings.longestStreakLabel(14)), findsOneWidget);
  });

  testWidgets('a result from a day that has ended says a new puzzle is '
      'ready', (tester) async {
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(null));
    final now = DateTime.now();
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/results',
          builder: (_, _) => ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 12,
              improved: false,
              replayDaily: true,
              gameId: GameIds.sudoku,
              // Started before midnight, finished after it.
              day: DateTime(now.year, now.month, now.day - 1),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.newPuzzleReady), findsOneWidget);
    expect(find.text(AppStrings.newPuzzleUnlocksTomorrow), findsNothing);
  });

  testWidgets('Daily clear sends the player home, not back into the puzzle', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Text('path-words'),
        ),
        GoRoute(path: '/zip', builder: (_, _) => const Text('zip')),
        GoRoute(
          path: '/results',
          builder: (_, _) => const ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 12,
              improved: false,
              replayDaily: true,
              replayRoute: '/path-words',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.playAgain), findsNothing);
    expect(find.text(AppStrings.newPuzzleUnlocksTomorrow), findsOneWidget);

    await tester.tap(find.text(AppStrings.backHome));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('path-words'), findsNothing);
    expect(find.text('zip'), findsNothing);
  });

  testWidgets('Non-daily Play again still opens the finished game', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(
          path: '/word-match/animals',
          builder: (_, _) => const Text('word-match'),
        ),
        GoRoute(
          path: '/results',
          builder: (_, _) => const ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 12,
              improved: false,
              replayRoute: '/word-match/animals',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.playAgain));
    await tester.pumpAndSettle();

    expect(find.text('word-match'), findsOneWidget);
  });

  testWidgets('a new badge shows under the daily result', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _MockAuthRepository();
    const me = AppUser(uid: 'u1', displayName: 'Tester');
    when(() => auth.currentUser).thenReturn(me);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(me));
    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => Stream.value(const []));
    final claim = _MockClaimNewAchievements();
    late final ResultsArgs args;
    when(
      () => claim.pending(occasion: any(named: 'occasion')),
    ).thenAnswer((_) async => [Achievements.byId('perfect_day')!]);
    when(
      () => claim.markShown(any(), occasion: any(named: 'occasion')),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<ClaimNewAchievements>.value(value: claim),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: ResultsScreen(
              args: args = ResultsArgs(
                title: 'Puzzle cleared!',
                subtitle: '',
                timeSeconds: 72,
                improved: false,
                replayDaily: true,
                gameId: GameIds.sudoku,
                day: DateTime.now(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.newAchievementsTitle(1)), findsOneWidget);
    expect(find.text(AppStrings.achievementPerfectDayTitle), findsOneWidget);
    verify(() => claim.pending(occasion: args)).called(1);
    verify(
      () =>
          claim.markShown([Achievements.byId('perfect_day')!], occasion: args),
    ).called(1);
  });
}
