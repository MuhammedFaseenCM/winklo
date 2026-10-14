import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
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
  SudokuBloc failingBloc(Object error) {
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
      hintQuota: _MockHintQuota(),
      inProgressRuns: _NoRuns(),
      generatePuzzle: ({required DateTime day}) => throw error,
      now: () => DateTime(2026, 10, 14),
    );
  }

  // The screen pauses the run as it unmounts, so unmount before the
  // tear-down closes the bloc.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  Future<void> pumpSudoku(WidgetTester tester, SudokuBloc bloc) async {
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
    await tester.pumpWidget(
      MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
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
}
