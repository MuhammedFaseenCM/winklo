import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/leaderboard/view/leaderboard_screen.dart';

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
}
