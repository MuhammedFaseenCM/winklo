import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
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

import '../../../helpers/screenshot.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockLeagueRepository extends Mock implements LeagueRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

const _me = AppUser(uid: 'me', displayName: 'Faseen');

const _names = [
  'Aisha K',
  'Rahul Menon Kuttikkattil',
  'Neha P',
  'Arjun S',
  'Fathima R',
  'Vivek T',
  'Meera J',
  'Sanjay D',
  'Ann V',
  'Rohit G',
  'Divya L',
  'Kiran B',
  'Joel M',
  'Faseen',
  'Priya N',
  'Hari C',
  'Lakshmi S',
  'Nikhil A',
];

List<LeaderboardEntry> _daily() => [
  for (var i = 0; i < _names.length; i++)
    LeaderboardEntry(
      uid: _names[i] == 'Faseen' ? 'me' : 'p$i',
      displayName: _names[i],
      timeSeconds: 42 + i * 5,
      updatedAt: DateTime.utc(2026, 10, 17),
      rank: i + 1,
      usedHints: i.isEven ? false : null,
      currentStreak: i % 3 == 0 ? 5 + i : null,
    ),
];

List<LeaderboardEntry> _weekly() => [
  for (var i = 0; i < _names.length; i++)
    LeaderboardEntry(
      uid: _names[i] == 'Faseen' ? 'me' : 'p$i',
      displayName: _names[i],
      timeSeconds: 300 + i * 41,
      updatedAt: DateTime.utc(2026, 10, 17),
      rank: i + 1,
      daysCleared: 6 - i ~/ 4,
    ),
];

/// The Leaderboard tab with a full board, rendered for review: no overflow,
/// and with `WINKLO_SCREENSHOTS=1`, PNGs in build/screenshots/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late StreamController<List<LeaderboardEntry>> board;
  late _MockWatchLeaderboard watch;

  setUpAll(() async {
    // Avatars and medals are cached network images; their cache would ask
    // for a directory no test host has. It waits instead.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) => Completer<Object?>().future,
        );
    await loadScreenshotFonts();
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  setUp(() {
    board = StreamController<List<LeaderboardEntry>>.broadcast();
    watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => board.stream);
    when(
      () => watch.members(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        memberUids: any(named: 'memberUids'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => board.stream);
  });

  tearDown(() => board.close());

  const boundary = Key('leaderboard_shot');

  Future<List<FlutterErrorDetails>> pump(WidgetTester tester, Size size) async {
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
    when(() => auth.currentUser).thenReturn(_me);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(_me));
    final leagues = _MockLeagueRepository();
    when(() => leagues.watchMyLeagues(any())).thenAnswer(
      (_) => Stream.value(const [
        League(
          id: 'L1',
          name: 'Thursday night puzzle club',
          ownerUid: 'me',
          code: 'ABC234',
          memberUids: ['me', 'p0', 'p1', 'p2', 'p3', 'p4', 'p5'],
        ),
        League(
          id: 'L2',
          name: 'Family',
          ownerUid: 'p2',
          code: 'XYZ789',
          memberUids: ['me', 'p2', 'p6'],
        ),
      ]),
    );
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
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<WatchLeaderboard>.value(value: watch),
            RepositoryProvider<AuthRepository>.value(value: auth),
            RepositoryProvider<LeagueRepository>.value(value: leagues),
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
    await tester.pump();
    await tester.pump();
    return overflows;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
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

    testWidgets('daily board, $tag', (tester) async {
      final overflows = await pump(tester, size);
      board.add(_daily());
      await settle(tester);
      await shot(tester, overflows, 'leaderboard_daily_$tag');
    });

    testWidgets('weekly board, $tag', (tester) async {
      final overflows = await pump(tester, size);
      await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('leaderboard_board_weekly')));
      await settle(tester);
      board.add(_weekly());
      await settle(tester);
      await shot(tester, overflows, 'leaderboard_weekly_$tag');
    });

    testWidgets('board sheet, $tag', (tester) async {
      final overflows = await pump(tester, size);
      board.add(_daily());
      await settle(tester);
      await tester.tap(find.byKey(const Key('leaderboard_board_pill')));
      await settle(tester);
      await shot(tester, overflows, 'leaderboard_board_sheet_$tag');
    });

    testWidgets('scope sheet, $tag', (tester) async {
      final overflows = await pump(tester, size);
      board.add(_daily());
      await settle(tester);
      await tester.tap(find.byKey(const Key('leaderboard_scope_pill')));
      await settle(tester);
      await shot(tester, overflows, 'leaderboard_scope_sheet_$tag');
    });
  }

  testWidgets('a league with a long name, 360x640', (tester) async {
    final overflows = await pump(tester, const Size(360, 640));
    board.add(_daily());
    await settle(tester);
    await tester.tap(find.byKey(const Key('leaderboard_scope_pill')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('leaderboard_scope_L1')));
    await settle(tester);
    board.add(_daily().take(7).toList());
    await settle(tester);
    await shot(tester, overflows, 'leaderboard_league_360x640');
  });
}
