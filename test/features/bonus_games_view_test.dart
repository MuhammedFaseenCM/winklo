import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/bonus_game_chrome.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/data/repositories/tutorial_repository_impl.dart';
import 'package:winklo/domain/entities/word_category.dart';
import 'package:winklo/domain/entities/word_match_deck.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/play_mode_record_repository.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/domain/usecases/fetch_categories.dart';
import 'package:winklo/domain/usecases/fetch_word_match_decks.dart';
import 'package:winklo/features/category_race/view/category_race_screen.dart';
import 'package:winklo/features/word_match/view/word_match_select_screen.dart';

import '../helpers/mock_analytics_repository.dart';
import '../helpers/screenshot.dart';

class _MockFetchDecks extends Mock implements FetchWordMatchDecks {}

class _MockFetchCategories extends Mock implements FetchCategories {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(loadScreenshotFonts);

  late SharedPreferences prefs;
  late MockAnalyticsRepository analytics;
  late _MockFetchDecks fetchDecks;
  late _MockFetchCategories fetchCategories;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(
      () => analytics.logTutorialShown(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logTutorialDismissed(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
    fetchDecks = _MockFetchDecks();
    fetchCategories = _MockFetchCategories();
    when(() => fetchDecks()).thenAnswer(
      (_) async => const [
        WordMatchDeck(
          id: 'opposites',
          title: 'Opposites',
          seconds: 60,
          pairs: [
            WordPair(a: 'hot', b: 'cold'),
            WordPair(a: 'up', b: 'down'),
          ],
        ),
        WordMatchDeck(
          id: 'animals',
          title: 'Animal sounds',
          seconds: 45,
          pairs: [WordPair(a: 'cat', b: 'meow')],
        ),
      ],
    );
    when(() => fetchCategories()).thenAnswer(
      (_) async => const [
        WordCategory(id: 'fruits', name: 'Fruits', words: ['apple', 'banana']),
      ],
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen, {Key? boundary}) async {
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<TutorialRepository>.value(
            value: TutorialRepositoryImpl(prefs),
          ),
          RepositoryProvider<PlayModeRecordRepository>.value(
            value: PlayModeRecordRepositoryImpl(prefs),
          ),
          RepositoryProvider<FetchWordMatchDecks>.value(value: fetchDecks),
          RepositoryProvider<FetchCategories>.value(value: fetchCategories),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp.router(
            theme: buildAppTheme(),
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('How to play opens on the first round only', (tester) async {
    await pump(tester, const CategoryRaceScreen());
    expect(find.text(AppStrings.categoryRaceHowToBody), findsOneWidget);
    await tester.tap(find.text(AppStrings.tutorialGotIt));
    await tester.pumpAndSettle();
    expect(prefs.getBool('tutorial_seen_${GameIds.categoryRace}'), isTrue);

    await pump(tester, const SizedBox());
    await pump(tester, const CategoryRaceScreen());
    expect(find.text(AppStrings.categoryRaceHowToBody), findsNothing);
    expect(find.text('Fruits'), findsOneWidget);
    expect(find.text(AppStrings.categoryRaceStart(60)), findsOneWidget);
  });

  testWidgets('the help button reopens the rules', (tester) async {
    await prefs.setBool('tutorial_seen_${GameIds.categoryRace}', true);
    await pump(tester, const CategoryRaceScreen());
    await tester.tap(find.byIcon(AppIcons.help));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.categoryRaceHowToBody), findsOneWidget);
  });

  testWidgets('BonusHowToPlay without a tutorial store does nothing', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await BonusHowToPlay.maybeShow(
      captured,
      gameId: GameIds.wordMatch,
      title: 'x',
      body: 'y',
    );
    await tester.pump();
    expect(find.text('y'), findsNothing);
  });

  testWidgets('Word Match decks at 360x640, with a local best', (tester) async {
    await prefs.setBool('tutorial_seen_${GameIds.wordMatch}', true);
    await PlayModeRecordRepositoryImpl(
      prefs,
    ).recordTime('bonus_word_match_opposites', 38);
    const boundary = Key('word-match');
    await pump(tester, const WordMatchSelectScreen(), boundary: boundary);
    expect(tester.takeException(), isNull);
    expect(find.text('Opposites'), findsOneWidget);
    expect(find.text(AppStrings.localBest('0:38')), findsOneWidget);
    expect(find.text(AppStrings.wordMatchPairs(2)), findsOneWidget);
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'word_match_decks_360x640',
    );
  });

  testWidgets('Category Race at 360x640', (tester) async {
    await prefs.setBool('tutorial_seen_${GameIds.categoryRace}', true);
    const boundary = Key('category-race');
    await pump(tester, const CategoryRaceScreen(), boundary: boundary);
    expect(tester.takeException(), isNull);
    await saveScreenshot(tester, find.byKey(boundary), 'category_race_360x640');
  });
}
