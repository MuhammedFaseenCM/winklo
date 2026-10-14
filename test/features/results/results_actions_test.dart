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
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/next_uncleared_daily.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';

import '../../helpers/mock_analytics_repository.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNextUnclearedDaily extends Mock implements NextUnclearedDaily {}

void main() {
  const user = AppUser(uid: 'u1', displayName: 'Tester');

  late _MockAuthRepository auth;
  late _MockWatchLeaderboard watch;
  late _MockNextUnclearedDaily next;
  late MockAnalyticsRepository analytics;
  late StreamController<List<LeaderboardEntry>> board;

  setUpAll(() => registerFallbackValue(LeaderboardPeriod.daily));

  setUp(() {
    auth = _MockAuthRepository();
    watch = _MockWatchLeaderboard();
    next = _MockNextUnclearedDaily();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    board = StreamController<List<LeaderboardEntry>>.broadcast();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => board.stream);
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
  });

  tearDown(() => board.close());

  Future<void> pumpZipResults(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/path-words',
          builder: (_, _) => const Text('path words game'),
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, state) =>
              Text('board ${state.uri.queryParameters['game']}'),
        ),
        GoRoute(
          path: '/results',
          builder: (_, _) => const ResultsScreen(
            args: ResultsArgs(
              title: 'Puzzle cleared!',
              subtitle: '',
              timeSeconds: 72,
              improved: false,
              replayDaily: true,
              gameId: GameIds.zip,
              usedHints: false,
              currentStreak: 5,
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
          RepositoryProvider<NextUnclearedDaily>.value(value: next),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
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
    board.add(const []);
    await tester.pumpAndSettle();
  }

  void nextIs(String? gameId) {
    when(
      () => next(
        justCleared: any(named: 'justCleared'),
        playId: any(named: 'playId'),
      ),
    ).thenReturn(gameId);
  }

  testWidgets('offers the next uncleared daily and opens it', (tester) async {
    nextIs(GameIds.pathWords);
    await pumpZipResults(tester);

    final label = AppStrings.playNextGame(AppStrings.pathWordsTitle);
    expect(find.text(label), findsOneWidget);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(find.text('path words game'), findsOneWidget);
    verify(
      () =>
          analytics.logResultsAction(gameId: GameIds.zip, action: 'play_next'),
    ).called(1);
  });

  testWidgets('with every daily cleared, celebrates a perfect day', (
    tester,
  ) async {
    nextIs(null);
    await pumpZipResults(tester);

    expect(find.text(AppStrings.perfectDay), findsOneWidget);
    expect(find.textContaining('next'), findsNothing);
  });

  testWidgets('full leaderboard and home log their results_action', (
    tester,
  ) async {
    nextIs(GameIds.sudoku);
    await pumpZipResults(tester);

    await tester.tap(find.text(AppStrings.seeFullLeaderboard));
    await tester.pumpAndSettle();
    expect(find.text('board zip'), findsOneWidget);
    verify(
      () => analytics.logResultsAction(
        gameId: GameIds.zip,
        action: 'leaderboard',
      ),
    ).called(1);
  });

  testWidgets('back home logs its results_action', (tester) async {
    nextIs(GameIds.sudoku);
    await pumpZipResults(tester);

    await tester.tap(find.text(AppStrings.backHome));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    verify(
      () => analytics.logResultsAction(gameId: GameIds.zip, action: 'home'),
    ).called(1);
  });
}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}
