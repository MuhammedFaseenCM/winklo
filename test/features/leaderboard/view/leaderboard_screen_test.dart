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
import 'package:winklo/features/leaderboard/view/leaderboard_screen.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_shimmer.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  testWidgets('query game change selects game on a kept cubit', (tester) async {
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);
    final games = <String>[];

    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      games.add(invocation.namedArguments[#gameId] as String);
      return boardController.stream;
    });

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const Text('home')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/leaderboard',
                  builder: (context, state) {
                    final game = state.uri.queryParameters['game'];
                    return LeaderboardScreen(
                      initialGameId: game == GameIds.pathWords
                          ? GameIds.pathWords
                          : GameIds.zip,
                    );
                  },
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

    router.go('/leaderboard');
    await tester.pump();
    await tester.pump();

    expect(games, contains(GameIds.zip));
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    router.go('/leaderboard?game=${GameIds.pathWords}');
    await tester.pump();
    await tester.pump();

    expect(games.last, GameIds.pathWords);
    final button = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(button.selected, {GameIds.pathWords});
  });

  Future<void> pumpLeaderboard(
    WidgetTester tester, {
    required AuthCubit authCubit,
    required _MockAuthRepository auth,
    required _MockWatchLeaderboard watch,
    bool showAllTimeLeaderboard = true,
  }) async {
    addTearDown(authCubit.close);
    final router = GoRouter(
      initialLocation: '/leaderboard',
      routes: [
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) =>
              LeaderboardScreen(showAllTimeLeaderboard: showAllTimeLeaderboard),
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
  }

  testWidgets('auth unknown shows LeaderboardShimmer not sign-in CTA', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final authController = StreamController<AppUser?>.broadcast();
    addTearDown(authController.close);

    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => authController.stream);
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => const Stream.empty());

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    expect(find.byType(LeaderboardShimmer), findsOneWidget);
    expect(find.text(AppStrings.signInWithGoogle), findsNothing);
  });

  testWidgets('signed-in loading shows LeaderboardShimmer', (tester) async {
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    expect(find.byType(LeaderboardShimmer), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('signed-in empty leaderboard shows message and play button', (
    tester,
  ) async {
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    // Emit empty leaderboard
    boardController.add([]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardEmpty), findsOneWidget);
    expect(find.text('Play ${AppStrings.zipTitle}'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    // Switch game to Path Words
    await tester.tap(find.text(AppStrings.pathWordsTitle));
    await tester.pump();

    boardController.add([]);
    await tester.pump();

    expect(find.text('Play ${AppStrings.pathWordsTitle}'), findsOneWidget);
  });

  testWidgets('user at rank 20 shows pinned user tile at bottom', (
    tester,
  ) async {
    const user = AppUser(uid: 'u20', displayName: 'Player 20');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    // Create 25 entries where user is rank 20
    final entries = List.generate(
      25,
      (i) => LeaderboardEntry(
        uid: 'u${i + 1}',
        displayName: 'Player ${i + 1}',
        timeSeconds: 20 + i,
        updatedAt: DateTime.utc(2026, 9, 25),
        rank: i + 1,
      ),
    );

    boardController.add(entries);
    await tester.pumpAndSettle();

    // The pinned row displays 'Your Rank' and user's name
    expect(find.text('Your Rank'), findsOneWidget);
    expect(find.text('Player 20'), findsOneWidget);
  });

  testWidgets('user at rank 2 does not show pinned user tile', (tester) async {
    const user = AppUser(uid: 'u2', displayName: 'Player 2');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    final entries = List.generate(
      25,
      (i) => LeaderboardEntry(
        uid: 'u${i + 1}',
        displayName: 'Player ${i + 1}',
        timeSeconds: 20 + i,
        updatedAt: DateTime.utc(2026, 9, 25),
        rank: i + 1,
      ),
    );

    boardController.add(entries);
    await tester.pumpAndSettle();

    // Since user is rank 2 (in initial loaded list), pinned tile should not be shown
    expect(find.text('Your Rank'), findsNothing);
  });

  testWidgets('scrolling down to user rank 20 hides pinned tile', (
    tester,
  ) async {
    const user = AppUser(uid: 'u20', displayName: 'Player 20');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    final entries = List.generate(
      25,
      (i) => LeaderboardEntry(
        uid: 'u${i + 1}',
        displayName: 'Player ${i + 1}',
        timeSeconds: 20 + i,
        updatedAt: DateTime.utc(2026, 9, 25),
        rank: i + 1,
      ),
    );

    boardController.add(entries);
    await tester.pumpAndSettle();

    // Pinned row is visible initially
    expect(find.text('Your Rank'), findsOneWidget);

    // Scroll down 1200 pixels towards rank 20
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    // Now user has scrolled and reached rank 20; pinned tile hides
    expect(find.text('Your Rank'), findsNothing);
  });

  testWidgets('signed-out shows live entries and floating sign-in CTA', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(null));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    boardController.add([
      LeaderboardEntry(
        uid: 'a',
        displayName: 'Alex',
        timeSeconds: 42,
        updatedAt: DateTime.utc(2026, 9, 27),
        rank: 1,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text(AppStrings.leaderboardSignInHint), findsNothing);
    expect(find.byKey(const Key('leaderboard_sign_in_fab')), findsOneWidget);
    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
  });

  testWidgets('signed-in does not show floating sign-in CTA', (tester) async {
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
    );

    boardController.add([
      LeaderboardEntry(
        uid: 'u1',
        displayName: 'Ada',
        timeSeconds: 40,
        updatedAt: DateTime.utc(2026, 9, 27),
        rank: 1,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leaderboard_sign_in_fab')), findsNothing);
  });

  testWidgets('hides All-time period when showAllTimeLeaderboard is false', (
    tester,
  ) async {
    final auth = _MockAuthRepository();
    final watch = _MockWatchLeaderboard();
    final periods = <LeaderboardPeriod>[];
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);

    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      periods.add(invocation.namedArguments[#period] as LeaderboardPeriod);
      return boardController.stream;
    });

    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    await pumpLeaderboard(
      tester,
      authCubit: authCubit,
      auth: auth,
      watch: watch,
      showAllTimeLeaderboard: false,
    );
    await tester.pump();

    expect(find.text(AppStrings.leaderboardAllTime), findsNothing);
    expect(find.text(AppStrings.leaderboardDaily), findsNothing);
    expect(periods, isNotEmpty);
    expect(periods, everyElement(LeaderboardPeriod.daily));
  });
}
