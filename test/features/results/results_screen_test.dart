import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';
import 'package:winklo/features/results/view/mini_leaderboard_panel.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  testWidgets('Zip clear shows mini leaderboard, not score card', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final boardController = StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'u1', displayName: 'Tester'),
    );
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

    expect(find.byType(MiniLeaderboardPanel), findsOneWidget);
    expect(find.text(AppStrings.seeFullLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.backHome), findsOneWidget);
    expect(find.text(AppStrings.newPersonalBest), findsNothing);
    expect(find.text('points'), findsNothing);
    expect(find.text('time'), findsNothing);
  });

  testWidgets('Path Words clear shows mini leaderboard panel', (tester) async {
    final auth = _MockAuthRepository();
    final boardController = StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'u1', displayName: 'Tester'),
    );
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

    expect(find.byType(MiniLeaderboardPanel), findsOneWidget);
  });

  testWidgets('MiniLeaderboardPanel lists entries when signed in', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final boardController = StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'uid1', displayName: 'Tester'),
    );
    when(() => auth.authStateChanges()).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'uid1', displayName: 'Tester')),
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
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
}
