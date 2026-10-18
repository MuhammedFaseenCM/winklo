import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/path_words_clear_summary.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';

import '../../helpers/mock_analytics_repository.dart';
import '../../helpers/screenshot.dart';

ResultsArgs _archiveArgs({
  bool improved = false,
  int best = 75,
  int hintPenaltySeconds = 0,
}) => ResultsArgs(
  title: AppStrings.zipClearedTitle,
  subtitle: '',
  timeSeconds: 75,
  improved: improved,
  gameId: GameIds.zip,
  usedHints: hintPenaltySeconds > 0,
  hintPenaltySeconds: hintPenaltySeconds,
  day: DateTime(2026, 10, 12),
  local: LocalResultInfo(
    kind: LocalResultKind.archive,
    label: AppStrings.archiveRunLabel(DateTime(2026, 10, 12)),
    bestSeconds: best,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(loadScreenshotFonts);

  Future<void> pump(
    WidgetTester tester,
    ResultsArgs args, {
    Size size = const Size(360, 640),
    Key? boundary,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/start',
          builder: (context, _) => TextButton(
            onPressed: () => context.push('/results', extra: args),
            child: const Text('open'),
          ),
        ),
        GoRoute(
          path: '/results',
          builder: (_, state) =>
              ResultsScreen(args: state.extra! as ResultsArgs),
        ),
        GoRoute(path: '/more', builder: (_, _) => const Text('hub')),
        GoRoute(
          path: '/more/archive',
          builder: (_, _) => const Text('archive page'),
        ),
        GoRoute(path: '/zip', builder: (_, state) => Text('${state.uri}')),
      ],
    );
    await tester.pumpWidget(
      RepositoryProvider<AnalyticsRepository>.value(
        value: analytics,
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
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the time, Archive · 12 Oct and the archive best', (
    tester,
  ) async {
    await pump(tester, _archiveArgs(improved: true, best: 75));
    expect(find.text('1:15'), findsOneWidget);
    expect(find.text('Archive · 12 Oct'), findsOneWidget);
    expect(find.text(AppStrings.archiveBest('1:15')), findsOneWidget);
    expect(find.text(AppStrings.newLocalBest), findsOneWidget);
    expect(find.textContaining('from hints'), findsNothing);
  });

  testWidgets('says how much time hints added to the time', (tester) async {
    await pump(tester, _archiveArgs(hintPenaltySeconds: 30));
    expect(find.text('1:15'), findsOneWidget);
    expect(find.text(AppStrings.resultsHintPenalty(30)), findsOneWidget);
  });

  testWidgets('has no board, streak, share or achievements', (tester) async {
    await pump(tester, _archiveArgs());
    expect(find.text(AppStrings.shareResult), findsNothing);
    expect(find.text(AppStrings.resultsFullBoard), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
    expect(find.textContaining('board'), findsNothing);
    expect(find.text(AppStrings.newPersonalBest), findsNothing);
    expect(find.text(AppStrings.saveTimeSignInTitle), findsNothing);
  });

  testWidgets('Back to archive returns to the archive', (tester) async {
    await pump(tester, _archiveArgs());
    await tester.tap(find.text(AppStrings.backToArchive));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('practice offers New board', (tester) async {
    await pump(
      tester,
      ResultsArgs(
        title: AppStrings.zipClearedTitle,
        subtitle: '',
        timeSeconds: 40,
        improved: false,
        gameId: GameIds.zip,
        local: LocalResultInfo(
          kind: LocalResultKind.practice,
          label: AppStrings.practiceRunLabel,
          bestSeconds: 31,
          againLocation: '/zip?mode=practice',
        ),
      ),
    );
    expect(find.text(AppStrings.localBest('0:31')), findsOneWidget);
    await tester.tap(find.text(AppStrings.practiceNewBoard));
    await tester.pumpAndSettle();
    expect(find.text('/zip?mode=practice'), findsOneWidget);
  });

  testWidgets('a score run shows words and the best score', (tester) async {
    await pump(
      tester,
      const ResultsArgs(
        title: 'Round over',
        subtitle: '',
        timeSeconds: 60,
        improved: false,
        gameId: GameIds.categoryRace,
        local: LocalResultInfo(
          kind: LocalResultKind.bonus,
          label: 'Category Race · Animals',
          score: 7,
          bestScore: 9,
          againLocation: '/category-race',
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.text(AppStrings.localBestScore(9)), findsOneWidget);
    expect(find.text(AppStrings.playAgain), findsOneWidget);
  });

  testWidgets('archive Results at 360x640 fit without overflow', (
    tester,
  ) async {
    const boundary = Key('local-results');
    await pump(
      tester,
      ResultsArgs(
        title: AppStrings.pathWordsClearedTitle,
        subtitle: '',
        timeSeconds: 75,
        improved: true,
        gameId: GameIds.pathWords,
        day: DateTime(2026, 10, 12),
        pathWords: const PathWordsClearSummary(
          theme: 'In the kitchen',
          words: ['kettle', 'ladle', 'whisk', 'grater', 'sieve'],
        ),
        local: LocalResultInfo(
          kind: LocalResultKind.archive,
          label: AppStrings.archiveRunLabel(DateTime(2026, 10, 12)),
          bestSeconds: 75,
        ),
      ),
      boundary: boundary,
    );
    expect(tester.takeException(), isNull);
    await saveScreenshot(
      tester,
      find.byKey(boundary),
      'results_archive_360x640',
    );
  });
}
