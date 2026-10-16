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

  Future<GoRouter> pump(
    WidgetTester tester, {
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
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

  /// Lets a sheet open or close. Not pumpAndSettle: a loading board's
  /// shimmer never settles.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openBoardSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
    await settle(tester);
  }

  Future<void> openScopeSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('leaderboard_scope_pill')));
    await settle(tester);
  }

  testWidgets('fits a 360×640 phone with both pills showing', (tester) async {
    await pump(tester);
    board.add([_ada, _bo]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.leaderboardToday), findsOneWidget);
    expect(find.text(AppStrings.leaderboardScopeEveryone), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTime), findsOneWidget);
    expect(find.byKey(const Key('leaderboard_manage_leagues')), findsNothing);
    // Screen readers can open both pickers.
    for (final key in ['leaderboard_board_pill', 'leaderboard_scope_pill']) {
      expect(
        tester.getSemantics(find.byKey(Key(key))),
        isSemantics(isButton: true, hasTapAction: true),
        reason: key,
      );
    }
  });

  testWidgets('a 390×800 phone shows at least nine rows', (tester) async {
    await pump(tester, size: const Size(390, 800));
    board.add([
      for (var i = 1; i <= 20; i++)
        LeaderboardEntry(
          uid: 'p$i',
          displayName: 'Player $i',
          timeSeconds: 40 + i,
          updatedAt: DateTime.utc(2026, 10, 15),
          rank: i,
        ),
    ]);
    await tester.pumpAndSettle();

    // Above the 88px nav dock.
    expect(tester.getRect(find.text('Player 9')).bottom, lessThan(800 - 88));
  });

  testWidgets('a past day loads that day’s board', (tester) async {
    await pump(tester);
    board.add([_ada]);
    await tester.pumpAndSettle();

    final yesterday = leaderboardDayId(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    await openBoardSheet(tester);
    await tester.tap(find.byKey(Key('leaderboard_day_$yesterday')));
    await settle(tester);

    expect(calls.last.dayId, yesterday);
    expect(find.text(AppStrings.leaderboardYesterday), findsOneWidget);

    board.add(const []);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardPastDayEmpty), findsOneWidget);
  });

  testWidgets('This week shows days and total columns', (tester) async {
    await pump(tester);
    await openBoardSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardThisWeek));
    await settle(tester);
    expect(calls.last.period, LeaderboardPeriod.weekly);

    board.add([_bo]);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.leaderboardThisWeek), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnDays), findsOneWidget);
    expect(find.text(AppStrings.leaderboardColumnTotal), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6:12'), findsOneWidget);
  });

  testWidgets('All-time loads from the sheet', (tester) async {
    await pump(tester);
    await openBoardSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardAllTime));
    await settle(tester);
    expect(calls.last.period, LeaderboardPeriod.allTime);

    board.add([_ada]);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.leaderboardColumnBest), findsOneWidget);
  });

  testWidgets('an empty weekly board explains debug builds', (tester) async {
    await pump(tester);
    await openBoardSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardThisWeek));
    await settle(tester);
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

    await openScopeSheet(tester);
    await tester.tap(find.text('Family'));
    await settle(tester);

    expect(memberCalls.last, ['u1', 'u2']);
    expect(find.text('Family'), findsOneWidget);
  });

  testWidgets('Manage leagues opens the leagues screen', (tester) async {
    await pump(tester);
    board.add(const []);
    await tester.pumpAndSettle();

    await openScopeSheet(tester);
    await tester.tap(find.text(AppStrings.leaderboardManageLeagues));
    await tester.pumpAndSettle();

    expect(find.text('leagues screen'), findsOneWidget);
  });
}
