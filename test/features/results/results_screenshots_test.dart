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
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/entities/path_words_clear_summary.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/share_repository.dart';
import 'package:winklo/domain/usecases/next_uncleared_daily.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';

import '../../helpers/mock_analytics_repository.dart';
import '../../helpers/mock_app_review_repository.dart';
import '../../helpers/screenshot.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockNextUnclearedDaily extends Mock implements NextUnclearedDaily {}

class _MockShareRepository extends Mock implements ShareRepository {}

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

/// The daily Results screen, rendered for review: no overflow, and with
/// `WINKLO_SCREENSHOTS=1`, PNGs in build/screenshots/.
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
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  const boundary = Key('results_shot');

  Future<List<FlutterErrorDetails>> pump(
    WidgetTester tester, {
    required Size size,
    required AppUser? user,
    required List<LeaderboardEntry> entries,
    required ResultsArgs args,
    String? next,
  }) async {
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

    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => Stream.value(entries));
    final auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(
      () => auth.authStateChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    final nextDaily = _MockNextUnclearedDaily();
    when(
      () => nextDaily(
        justCleared: any(named: 'justCleared'),
        playId: any(named: 'playId'),
      ),
    ).thenReturn(next);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final review = MockAppReviewRepository();
    stubAppReviewNoAutoPrompt(review);
    final authCubit = AuthCubit(
      authRepository: auth,
      signInWithGoogle: _MockSignInWithGoogle(),
      signOut: _MockSignOut(),
    );
    addTearDown(authCubit.close);
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/results',
          builder: (_, _) => ResultsScreen(args: args),
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
            RepositoryProvider<NextUnclearedDaily>.value(value: nextDaily),
            RepositoryProvider<AnalyticsRepository>.value(value: analytics),
            RepositoryProvider<AppReviewRepository>.value(value: review),
            RepositoryProvider<ShareRepository>.value(
              value: _MockShareRepository(),
            ),
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
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return overflows;
  }

  final zipArgs = ResultsArgs(
    title: 'Puzzle cleared!',
    subtitle: '',
    timeSeconds: 107,
    improved: true,
    replayDaily: true,
    currentStreak: 6,
    longestStreak: 11,
    hintPenaltySeconds: 20,
    gameId: GameIds.zip,
    day: DateTime.now(),
  );

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('small', const Size(360, 640)),
  ]) {
    testWidgets('signed-in Zip results on a $name', (tester) async {
      final overflows = await pump(
        tester,
        size: size,
        user: _me,
        entries: _daily(),
        args: zipArgs,
        next: GameIds.pathWords,
      );
      await saveScreenshot(
        tester,
        find.byKey(boundary),
        'results_signed_in_$name',
      );
      expect(overflows, isEmpty);
    });
  }

  final pathWordsArgs = ResultsArgs(
    title: 'Puzzle cleared!',
    subtitle: '',
    timeSeconds: 107,
    improved: false,
    replayDaily: true,
    currentStreak: 6,
    longestStreak: 11,
    usedHints: false,
    gameId: GameIds.pathWords,
    day: DateTime.now(),
    pathWords: const PathWordsClearSummary(
      theme: 'Kitchen tools',
      words: ['ladle', 'kettle', 'whisk', 'grater', 'sieve'],
      definitions: {
        'ladle': 'A long-handled spoon with a deep bowl.',
        'whisk': 'A utensil for whipping eggs or cream.',
        'sieve': 'A mesh utensil for straining.',
      },
      bonusWords: ['tale', 'kit'],
    ),
  );

  testWidgets('signed-in Path Words results, board then words', (tester) async {
    final overflows = await pump(
      tester,
      size: const Size(390, 844),
      user: _me,
      entries: _daily(),
      args: pathWordsArgs,
      next: GameIds.sudoku,
    );
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_path_words_board',
    );
    await tester.tap(find.byKey(const Key('resultsWordsTab')));
    await tester.pumpAndSettle();
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_path_words_words',
    );
    expect(overflows, isEmpty);
  });

  testWidgets('Sudoku perfect day on a small phone', (tester) async {
    final overflows = await pump(
      tester,
      size: const Size(360, 640),
      user: _me,
      entries: [
        for (var i = 0; i < 9; i++)
          LeaderboardEntry(
            uid: i == 1 ? 'me' : 'p$i',
            displayName: i == 1 ? 'Faseen' : _names[i],
            timeSeconds: 340 + i * 23,
            updatedAt: DateTime.utc(2026, 10, 21),
            rank: i + 1,
            usedHints: i < 3 ? false : null,
            hadMistakes: i < 3 ? false : null,
          ),
      ],
      args: ResultsArgs(
        title: 'Puzzle cleared!',
        subtitle: '',
        timeSeconds: 363,
        improved: false,
        replayDaily: true,
        currentStreak: 3,
        usedHints: false,
        hadMistakes: false,
        gameId: GameIds.sudoku,
        day: DateTime.now(),
      ),
    );
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_sudoku_perfect_small',
    );
    expect(overflows, isEmpty);
  });

  testWidgets('guest Zip results', (tester) async {
    final overflows = await pump(
      tester,
      size: const Size(390, 844),
      user: null,
      entries: const [],
      args: zipArgs,
    );
    await saveScreenshot(tester, find.byKey(boundary), 'results_guest_phone');
    expect(overflows, isEmpty);
  });

  testWidgets('guest Path Words results on a small phone', (tester) async {
    final overflows = await pump(
      tester,
      size: const Size(360, 640),
      user: null,
      entries: const [],
      args: pathWordsArgs,
    );
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_guest_path_words_small',
    );
    expect(overflows, isEmpty);
  });

  testWidgets('signed-in Zip results sideways', (tester) async {
    final overflows = await pump(
      tester,
      size: const Size(844, 390),
      user: _me,
      entries: _daily(),
      args: zipArgs,
      next: GameIds.pathWords,
    );
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_signed_in_sideways',
    );
    expect(overflows, isEmpty);
  });

  testWidgets('Malayalam: signed-in Path Words on a small phone', (
    tester,
  ) async {
    AppStrings.use('ml');
    addTearDown(() => AppStrings.use('en'));
    final overflows = await pump(
      tester,
      size: const Size(360, 640),
      user: _me,
      entries: _daily(),
      args: ResultsArgs(
        title: AppStrings.pathWordsClearedTitle,
        subtitle: '',
        timeSeconds: 107,
        improved: true,
        replayDaily: true,
        currentStreak: 6,
        longestStreak: 11,
        usedHints: true,
        hintPenaltySeconds: 20,
        gameId: GameIds.pathWords,
        day: DateTime.now(),
        pathWords: pathWordsArgs.pathWords,
      ),
      next: GameIds.sudoku,
    );
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_ml_path_words_small',
    );
    expect(overflows, isEmpty);
  });
}
