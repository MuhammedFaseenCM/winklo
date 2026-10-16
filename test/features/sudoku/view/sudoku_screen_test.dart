import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_bloc.dart';
import 'package:winklo/features/sudoku/view/sudoku_screen.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockHintQuota extends Mock implements HintQuotaRepository {}

class _MockTutorialRepository extends Mock implements TutorialRepository {}

class _NoRuns implements InProgressRunRepository {
  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async => null;

  @override
  Future<void> save(InProgressRun run) async {}

  @override
  Future<void> clear({required String gameId, required String playId}) async {}
}

void main() {
  SudokuBloc buildBloc(
    SudokuPuzzle Function({required DateTime day}) generatePuzzle, {
    HintQuotaRepository? hintQuota,
  }) {
    final points = _MockGetBestPoints();
    final times = _MockGetBestTimeSeconds();
    when(() => points(any())).thenReturn(0);
    when(() => times(any())).thenReturn(null);
    final analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    return SudokuBloc(
      submitScore: _MockSubmitScore(),
      submitLeaderboardTime: _MockSubmitLeaderboardTime(),
      recordDailyClear: _MockRecordDailyClear(),
      getBestPoints: points,
      getBestTimeSeconds: times,
      isNewPersonalBest: _MockIsNewPersonalBest(),
      analytics: analytics,
      hintQuota: hintQuota ?? _MockHintQuota(),
      inProgressRuns: _NoRuns(),
      generatePuzzle: generatePuzzle,
      now: () => DateTime(2026, 10, 14),
    );
  }

  SudokuBloc failingBloc(Object error) =>
      buildBloc(({required DateTime day}) => throw error);

  // The screen pauses the run as it unmounts, so unmount before the
  // tear-down closes the bloc.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> pumpSudoku(
    WidgetTester tester,
    SudokuBloc bloc, {
    TutorialRepository? tutorials,
  }) async {
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/sudoku',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/sudoku',
          builder: (_, _) => SudokuScreen(bloc: bloc),
        ),
      ],
    );
    final app = MaterialApp.router(
      theme: buildAppTheme(),
      routerConfig: router,
    );
    await tester.pumpWidget(
      tutorials == null
          ? app
          : RepositoryProvider<TutorialRepository>.value(
              value: tutorials,
              child: app,
            ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a board this build cannot play asks for an update', (
    tester,
  ) async {
    final bloc = failingBloc(const UnsupportedPuzzle());
    await pumpSudoku(tester, bloc);

    expect(find.text(AppStrings.puzzleNeedsUpdate), findsOneWidget);
    expect(find.text(AppStrings.sudokuFailed), findsNothing);
    // Retrying can't help an old build; going home can.
    expect(find.text(AppStrings.retry), findsNothing);
    await tester.tap(find.text(AppStrings.backHome));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a puzzle that fails to load offers a retry', (tester) async {
    final bloc = failingBloc(const DailyPuzzleUnavailable());
    await pumpSudoku(tester, bloc);

    expect(find.text(AppStrings.sudokuFailed), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the first-run rules keep the clock stopped, even across '
      'leaving the app', (tester) async {
    const solution = [
      1, 2, 3, 4, 5, 6, //
      4, 5, 6, 1, 2, 3,
      2, 3, 1, 5, 6, 4,
      5, 6, 4, 2, 3, 1,
      3, 1, 2, 6, 4, 5,
      6, 4, 5, 3, 1, 2,
    ];
    // A 412 dp phone, not the default 800×600 test surface. (Debug builds add
    // a run timer to the header, and the test font is wider than the app's.)
    tester.view.physicalSize = const Size(1236, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final hints = _MockHintQuota();
    when(() => hints.usedFor(any(), any())).thenReturn(0);
    final bloc = buildBloc(
      ({required DateTime day}) => SudokuPuzzle(
        id: 'daily_20261014',
        dateId: '20261014',
        given: [for (var i = 0; i < 36; i++) i.isEven ? solution[i] : 0],
        solution: solution,
        difficulty: SudokuDifficulty.hard,
      ),
      hintQuota: hints,
    );
    final tutorials = _MockTutorialRepository();
    when(() => tutorials.hasSeen(any())).thenAnswer((_) async => false);
    when(() => tutorials.markSeen(any())).thenAnswer((_) async {});

    await pumpSudoku(tester, bloc, tutorials: tutorials);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(AppStrings.sudokuHowToPlayBody), findsOneWidget);
    expect(bloc.state.isClockRunning, isFalse);

    // Leaving and coming back must not start the clock behind the dialog.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(bloc.state.isClockRunning, isFalse);

    await tester.tap(find.text(AppStrings.sudokuHowToPlayGotIt));
    await tester.pump(const Duration(milliseconds: 300));
    expect(bloc.state.isClockRunning, isTrue);
    await unmount(tester);
  });
}
