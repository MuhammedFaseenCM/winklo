import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/app.dart';
import 'package:winklo/core/dev_flags.dart';
import 'package:winklo/core/di/app_repositories.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_language.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/game_day_record.dart';
import 'package:winklo/domain/entities/game_history.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/language_repository.dart';
import 'package:winklo/domain/repositories/league_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/sudoku/sudoku_generator.dart';
import 'package:winklo/domain/usecases/generate_daily_sudoku.dart';
import 'package:winklo/domain/usecases/load_game_history.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/home/view/home_screen.dart';
import 'package:winklo/features/home/view/widgets/home_update_banner.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/settings/cubit/locale_cubit.dart';
import 'package:winklo/features/settings/view/app_language_scope.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';

import '../../helpers/screenshot.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockSignIn extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockLanguages extends Mock implements LanguageRepository {}

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockLeagues extends Mock implements LeagueRepository {}

class _MockLoadHistory extends Mock implements LoadGameHistory {}

/// Today's Zip from the Dart generator (the real one comes from Firestore).
class _ZipLevels implements ZipLevelRepository {
  @override
  Future<ZipLevel> fetchDailyLevel(
    DateTime date, {
    Duration period = PlayPeriod.daily,
  }) async => DailyPuzzleGenerator.forDate(date, period: period);
}

/// Today's Sudoku from the Dart generator.
class _Sudoku extends GenerateDailySudoku {
  @override
  Future<SudokuPuzzle> call({required DateTime day, Duration? period}) async =>
      SudokuGenerator.practice(seed: 11);
}

const _user = AppUser(uid: 'me', displayName: 'Anu');

List<LeaderboardEntry> _board() => [
  for (final (i, (name, seconds)) in [
    ('Meera', 41),
    ('Arjun', 47),
    ('Anu', 52),
    ('Farhan', 58),
    ('Lakshmi', 64),
    ('Joseph', 71),
    ('Nila', 80),
  ].indexed)
    LeaderboardEntry(
      uid: name == 'Anu' ? 'me' : name,
      displayName: name,
      timeSeconds: seconds,
      updatedAt: DateTime.utc(2026, 10, 15),
      rank: i + 1,
      usedHints: i.isEven ? false : null,
      currentStreak: 3 + i,
    ),
];

String _id(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

GameHistory _history(DateTime today) => GameHistory(
  days: [
    for (var i = 30; i >= 0; i--)
      if (i % 4 != 3)
        GameDayRecord(
          gameId: GameIds.zip,
          playId: _id(DateTime(today.year, today.month, today.day - i)),
          timeSeconds: 40 + (i * 7) % 75,
          usedHints: i % 5 == 0,
          hadMistakes: false,
          flagsKnown: true,
        ),
  ],
  streaks: {
    GameIds.zip: GameStreak(
      gameId: GameIds.zip,
      current: 3,
      longest: 9,
      lastClearedDateId: _id(today),
    ),
    GameIds.pathWords: const GameStreak(gameId: GameIds.pathWords),
    GameIds.sudoku: const GameStreak(gameId: GameIds.sudoku),
  },
  today: today,
  remoteIncluded: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    DevFlags.disablePreviewFullProgressInTests = true;
    // Home's game art is a cached network image. Writing a PNG runs real
    // async, where the cache would ask for a directory no test host has; it
    // waits instead, and the art keeps its placeholder.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) => Completer<Object?>().future,
        );
    await loadScreenshotFonts();
    registerFallbackValue(LeaderboardPeriod.daily);
    registerFallbackValue(AppLanguage.system);
  });

  tearDownAll(() {
    DevFlags.disablePreviewFullProgressInTests = false;
  });

  tearDown(() => AppStrings.use('en'));

  const boundary = Key('malayalam_app');

  /// The whole app in Malayalam at 360×640, signed in, with today's Zip
  /// cleared, a 12-day Zip streak with two freezes, and a freeze that saved
  /// the Sudoku streak. Returns the app's router.
  Future<GoRouter> pumpApp(
    WidgetTester tester,
    List<FlutterErrorDetails> overflows, {
    bool tutorialsSeen = true,
  }) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) overflows.add(details);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final today = DateTime.now();
    final dayId = PlayPeriod.id(today, PlayPeriod.daily);
    final zipId = DailyPuzzleGenerator.dateId(today);
    SharedPreferences.setMockInitialValues({
      HomeScreen.permissionPromptedKey: true,
      for (final game in [GameIds.zip, GameIds.pathWords, GameIds.sudoku])
        'tutorial_seen_$game': tutorialsSeen,
      'best_time_zip_$zipId': 48,
      'streak_current_${GameIds.zip}': 12,
      'streak_longest_${GameIds.zip}': 12,
      'streak_last_${GameIds.zip}': dayId,
      'streak_freezes_${GameIds.zip}': 2,
      'streak_freeze_${GameIds.zip}': true,
      'streak_notice_freeze_saved': '[{"gameId":"sudoku","days":5}]',
    });
    final prefs = await SharedPreferences.getInstance();

    final auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(_user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(_user));
    final languages = _MockLanguages();
    when(() => languages.language).thenReturn(AppLanguage.malayalam);
    when(() => languages.setLanguage(any())).thenAnswer((_) async {});
    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => Stream.value(_board()));
    final leagues = _MockLeagues();
    when(
      () => leagues.watchMyLeagues(any()),
    ).thenAnswer((_) => Stream.value(const []));
    final history = _MockLoadHistory();
    when(
      () => history(refreshRemote: any(named: 'refreshRemote')),
    ).thenAnswer((_) async => _history(today));

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          ...buildRepositoryProviders(prefs: prefs),
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<LanguageRepository>.value(value: languages),
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<LeagueRepository>.value(value: leagues),
          RepositoryProvider<LoadGameHistory>.value(value: history),
          RepositoryProvider<ZipLevelRepository>.value(value: _ZipLevels()),
          RepositoryProvider<GenerateDailySudoku>.value(value: _Sudoku()),
        ],
        child: BlocProvider(
          lazy: false,
          create: (context) => LocaleCubit(
            languages: languages,
            deviceLanguageCodes: () => const ['en'],
          ),
          child: BlocProvider(
            create: (context) => AuthCubit(
              authRepository: auth,
              signInWithGoogle: _MockSignIn(),
              signOut: _MockSignOut(),
            ),
            child: const RepaintBoundary(key: boundary, child: WinkloApp()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(AppStrings.languageCode, 'ml');
    return GoRouter.of(tester.element(find.byType(HomeScreen)));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> check(
    WidgetTester tester,
    List<FlutterErrorDetails> overflows,
    String name,
  ) async {
    expect(overflows, isEmpty, reason: '$name: ${overflows.firstOrNull}');
    await saveScreenshot(tester, find.byKey(boundary), 'ml_$name');
  }

  Future<void> scrollDown(WidgetTester tester, Finder scrollable) async {
    await tester.drag(scrollable.first, const Offset(0, -500));
    await settle(tester);
  }

  testWidgets('Home', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    await pumpApp(tester, overflows);
    await settle(tester);
    expect(find.text('ഇന്നത്തെ Path Words കളിക്കൂ'), findsOneWidget);
    await check(tester, overflows, 'home');
    await scrollDown(tester, find.byType(Scrollable));
    await check(tester, overflows, 'home_scrolled');
  });

  testWidgets('Zip', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/zip?mode=practice');
    await settle(tester);
    expect(find.text(AppStrings.practiceNewBoard), findsOneWidget);
    await check(tester, overflows, 'zip_practice');
  });

  testWidgets('Path Words', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/path-words?mode=practice');
    await settle(tester);
    expect(find.text(AppStrings.practiceNewBoard), findsOneWidget);
    await check(tester, overflows, 'path_words_practice');
  });

  testWidgets('How to play, Zip and Sudoku', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows, tutorialsSeen: false);
    router.go('/zip?mode=practice');
    await settle(tester);
    expect(find.text(AppStrings.tutorialSkip), findsOneWidget);
    await check(tester, overflows, 'zip_how_to_play');
    router.go('/sudoku');
    await settle(tester);
    expect(find.text(AppStrings.sudokuHowToPlayBody), findsOneWidget);
    await check(tester, overflows, 'sudoku_how_to_play');
  });

  testWidgets('Sudoku', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/sudoku');
    await settle(tester);
    expect(find.text(AppStrings.sudokuNotes), findsOneWidget);
    await check(tester, overflows, 'sudoku');
  });

  testWidgets('Results', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go(
      '/results',
      extra: ResultsArgs(
        title: AppStrings.zipClearedTitle,
        subtitle: '',
        timeSeconds: 48,
        improved: true,
        replayDaily: true,
        replayRoute: '/zip',
        currentStreak: 12,
        longestStreak: 12,
        gameId: GameIds.zip,
        usedHints: false,
        hadMistakes: false,
        day: DateTime.now(),
      ),
    );
    await settle(tester);
    await check(tester, overflows, 'results');
    await scrollDown(tester, find.byType(Scrollable));
    await check(tester, overflows, 'results_scrolled');
  });

  testWidgets('Settings', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/profile/settings');
    await settle(tester);
    expect(find.text('ക്രമീകരണം'), findsOneWidget);
    await check(tester, overflows, 'settings');
    await scrollDown(tester, find.byType(Scrollable));
    await scrollDown(tester, find.byType(Scrollable));
    expect(find.text('മലയാളം'), findsOneWidget);
    await check(tester, overflows, 'settings_scrolled');
  });

  testWidgets('Stats', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/profile/stats');
    await settle(tester);
    expect(find.text(AppStrings.statsTitle), findsOneWidget);
    await check(tester, overflows, 'stats');
    await scrollDown(tester, find.byType(Scrollable));
    await check(tester, overflows, 'stats_scrolled');
  });

  testWidgets('More ways to play', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/more');
    await settle(tester);
    expect(find.text(AppStrings.moreWaysTitle), findsOneWidget);
    await check(tester, overflows, 'more_ways');
    await scrollDown(tester, find.byType(Scrollable));
    await check(tester, overflows, 'more_ways_scrolled');
  });

  testWidgets('Archive, leagues and the bonus games', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    for (final (location, name) in [
      ('/more/archive', 'archive'),
      ('/leagues', 'leagues'),
      ('/word-match', 'word_match'),
      ('/category-race', 'category_race'),
    ]) {
      router.go(location);
      await settle(tester);
      await check(tester, overflows, name);
    }
  });

  testWidgets('the update banner', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) overflows.add(details);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    AppStrings.use('ml');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          locale: const Locale('ml'),
          supportedLocales: AppLanguageScope.supportedLocales,
          localizationsDelegates: AppLanguageScope.localizationsDelegates,
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  HomeUpdateBanner(
                    currentLabel: '1.0.0+18',
                    requiredLabel: '1.1.0+19',
                    onUpdate: () {},
                    onSnooze: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('അപ്ഡേറ്റ് ലഭ്യമാണ്'), findsOneWidget);
    await check(tester, overflows, 'update_banner');
  });

  testWidgets('Leaderboard', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/leaderboard');
    await settle(tester);
    expect(find.text('Meera'), findsWidgets);
    await check(tester, overflows, 'leaderboard');
  });

  testWidgets('Profile', (tester) async {
    final overflows = <FlutterErrorDetails>[];
    final router = await pumpApp(tester, overflows);
    router.go('/profile');
    await settle(tester);
    await check(tester, overflows, 'profile');
    await scrollDown(tester, find.byType(Scrollable));
    await check(tester, overflows, 'profile_scrolled');
  });
}
