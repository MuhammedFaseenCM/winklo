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
import 'package:winklo/domain/entities/league.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/league_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/leaderboard/view/leaderboard_screen.dart';
import 'package:winklo/features/leaderboard/view/widgets/player_card_sheet.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLeagueRepository extends Mock implements LeagueRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

const _user = AppUser(uid: 'u1', displayName: 'Ada');

final _ada = LeaderboardEntry(
  uid: 'u1',
  displayName: 'Ada',
  timeSeconds: 75,
  updatedAt: DateTime.utc(2026, 10, 15),
  rank: 1,
  usedHints: false,
  currentStreak: 4,
);

final _bo = LeaderboardEntry(
  uid: 'u2',
  displayName: 'Bo',
  timeSeconds: 372,
  updatedAt: DateTime.utc(2026, 10, 15),
  rank: 2,
  daysCleared: 5,
);

/// Past days, the weekly tab, the player card and the league scope.
void main() {
  late _MockAuthRepository auth;
  late _MockWatchLeaderboard watch;
  late _MockLeagueRepository leagues;
  late StreamController<List<LeaderboardEntry>> board;
  late List<({LeaderboardPeriod period, String? dayId})> calls;
  late List<List<String>> memberCalls;

  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  setUp(() {
    auth = _MockAuthRepository();
    watch = _MockWatchLeaderboard();
    leagues = _MockLeagueRepository();
    board = StreamController<List<LeaderboardEntry>>.broadcast();
    calls = [];
    memberCalls = [];
    when(() => auth.currentUser).thenReturn(_user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(_user));
    when(() => leagues.watchMyLeagues(any())).thenAnswer(
      (_) => Stream.value(const [
        League(
          id: 'L1',
          name: 'Family',
          ownerUid: 'u1',
          code: 'ABC234',
          memberUids: ['u1', 'u2'],
        ),
      ]),
    );
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      calls.add((
        period: invocation.namedArguments[#period] as LeaderboardPeriod,
        dayId: invocation.namedArguments[#dayId] as String?,
      ));
      return board.stream;
    });
    when(
      () => watch.members(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        memberUids: any(named: 'memberUids'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((invocation) {
      memberCalls.add(invocation.namedArguments[#memberUids] as List<String>);
      return board.stream;
    });
  });

  tearDown(() => board.close());

  Future<GoRouter> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);
    final router = GoRouter(
      initialLocation: '/leaderboard',
      routes: [
        GoRoute(
          path: '/leaderboard',
          builder: (_, _) =>
              const LeaderboardScreen(showAllTimeLeaderboard: true),
        ),
        GoRoute(
          path: '/leagues',
          builder: (_, _) => const Scaffold(body: Text('leagues screen')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<LeagueRepository>.value(value: leagues),
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

  testWidgets('fits a 360×640 phone with every bar showing', (tester) async {
    await pump(tester);
    board.add([_ada, _bo]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.leaderboardThisWeek), findsOneWidget);
    expect(find.text(AppStrings.leaderboardToday), findsOneWidget);
    expect(find.text(AppStrings.leaderboardYesterday), findsOneWidget);
    expect(find.text(AppStrings.leaderboardScopeEveryone), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('a past day loads that day’s board', (tester) async {
    await pump(tester);
    board.add([_ada]);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.leaderboardYesterday));
    await tester.pump();

    final yesterday = leaderboardDayId(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(calls.last.dayId, yesterday);

    board.add(const []);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardPastDayEmpty), findsOneWidget);
  });

  testWidgets('the weekly tab hides the day strip and shows days and total', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.leaderboardThisWeek));
    await tester.pump();
    expect(calls.last.period, LeaderboardPeriod.weekly);

    board.add([_bo]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardToday), findsNothing);
    expect(find.text('5 days · 6:12'), findsOneWidget);
  });

  testWidgets('an empty weekly tab explains debug builds', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.leaderboardThisWeek));
    await tester.pump();
    board.add(const []);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardWeeklyDebugNote), findsOneWidget);
  });

  testWidgets('tapping a player opens their card', (tester) async {
    await pump(tester);
    board.add([_ada, _bo]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    final card = find.byType(PlayerCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('1:15')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(AppStrings.leaderboardNoHintChip),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(AppStrings.streakLabel(4))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a league shows its members', (tester) async {
    await pump(tester);
    board.add([_ada]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Family'));
    await tester.pump();

    expect(memberCalls.last, ['u1', 'u2']);
  });

  testWidgets('the Leagues chip opens the leagues screen', (tester) async {
    await pump(tester);
    board.add(const []);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('leaderboard_manage_leagues')));
    await tester.pumpAndSettle();

    expect(find.text('leagues screen'), findsOneWidget);
  });
}
