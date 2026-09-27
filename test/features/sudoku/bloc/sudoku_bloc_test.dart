import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_bloc.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_event.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_state.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

SudokuPuzzle _almostSolvedPuzzle({required DateTime day}) {
  final solution = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    4,
    5,
    6,
    1,
    2,
    3,
    2,
    3,
    1,
    5,
    6,
    4,
    5,
    6,
    4,
    2,
    3,
    1,
    3,
    1,
    2,
    6,
    4,
    5,
    6,
    4,
    5,
    3,
    1,
    2,
  ];
  final given = List<int>.from(solution);
  given[1] = 0; // only empty cell — solution digit 2
  return SudokuPuzzle(
    id: 'sudoku_test',
    dateId: '20260927',
    given: given,
    solution: solution,
    difficulty: SudokuDifficulty.easy,
  );
}

void main() {
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockAnalyticsRepository analytics;
  final day = DateTime(2026, 9, 27);

  SudokuBloc buildBloc({
    SudokuPuzzle Function({required DateTime day})? generatePuzzle,
    DateTime Function()? now,
  }) {
    return SudokuBloc(
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      analytics: analytics,
      generatePuzzle:
          generatePuzzle ??
          ({required DateTime day}) => _almostSolvedPuzzle(day: day),
      now: now ?? () => day,
      wait: (_) async {},
      celebrationDuration: Duration.zero,
    );
  }

  setUp(() {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    analytics = _MockAnalyticsRepository();
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    when(
      () => submitScore(
        modeKey: any(named: 'modeKey'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => submitLeaderboardTime(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => recordDailyClear(
        gameId: any(named: 'gameId'),
        dateId: any(named: 'dateId'),
      ),
    ).thenAnswer(
      (_) async => const GameStreak(
        gameId: GameIds.sudoku,
        current: 1,
        longest: 1,
        freezeAvailable: true,
      ),
    );
    when(
      () => analytics.logGameStarted(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logGameCompleted(
        gameId: any(named: 'gameId'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        streak: any(named: 'streak'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logHintUsed(
        gameId: any(named: 'gameId'),
        hintsRemaining: any(named: 'hintsRemaining'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logGameReset(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
  });

  blocTest<SudokuBloc, SudokuState>(
    'started loads puzzle and becomes ready',
    build: buildBloc,
    act: (bloc) => bloc.add(SudokuEvent.started(date: day)),
    expect: () => [
      isA<SudokuState>().having(
        (s) => s.status,
        'status',
        SudokuStatus.loading,
      ),
      isA<SudokuState>()
          .having((s) => s.status, 'status', SudokuStatus.ready)
          .having((s) => s.puzzle, 'puzzle', isNotNull)
          .having((s) => s.grid[1], 'empty cell', 0)
          .having((s) => s.startedAt, 'startedAt', isNotNull),
    ],
  );

  blocTest<SudokuBloc, SudokuState>(
    'started locks when already cleared',
    build: () {
      when(() => getBestPoints(any())).thenReturn(900);
      return buildBloc();
    },
    act: (bloc) => bloc.add(SudokuEvent.started(date: day)),
    expect: () => [
      isA<SudokuState>().having(
        (s) => s.status,
        'status',
        SudokuStatus.loading,
      ),
      isA<SudokuState>()
          .having((s) => s.status, 'status', SudokuStatus.locked)
          .having((s) => s.finished, 'finished', isTrue),
    ],
  );

  blocTest<SudokuBloc, SudokuState>(
    'wrong digit is rejected',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.digitTapped(3));
    },
    skip: 2, // loading + ready
    expect: () => [
      isA<SudokuState>().having((s) => s.selectedIndex, 'selected', 1),
      isA<SudokuState>()
          .having((s) => s.grid[1], 'grid', 0)
          .having((s) => s.rejectFlashIndex, 'reject', 1),
    ],
  );

  blocTest<SudokuBloc, SudokuState>(
    'correct digit then win submits score',
    build: () {
      var tick = 0;
      final times = [
        day,
        day,
        day.add(const Duration(seconds: 10)),
        day.add(const Duration(seconds: 10)),
      ];
      return buildBloc(
        now: () => times[tick < times.length ? tick++ : times.length - 1],
      );
    },
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.digitTapped(2));
    },
    verify: (bloc) {
      expect(bloc.state.status, SudokuStatus.navigating);
      expect(bloc.state.points, 950);
      expect(bloc.state.resultsExtra?.gameId, GameIds.sudoku);
      verify(
        () => submitScore(
          modeKey: any(named: 'modeKey', that: startsWith('sudoku_')),
          points: 950,
          timeSeconds: 10,
        ),
      ).called(1);
      verify(
        () => recordDailyClear(
          gameId: GameIds.sudoku,
          dateId: any(named: 'dateId'),
        ),
      ).called(1);
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'notes mode toggles candidate without placing digit',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.notesModeToggled());
      bloc.add(const SudokuEvent.digitTapped(3));
    },
    skip: 2,
    expect: () => [
      isA<SudokuState>().having((s) => s.selectedIndex, 'selected', 1),
      isA<SudokuState>().having((s) => s.notesMode, 'notes', isTrue),
      isA<SudokuState>().having((s) => s.grid[1], 'grid', 0).having(
        (s) => s.notes[1],
        'notes',
        {3},
      ),
    ],
  );

  blocTest<SudokuBloc, SudokuState>(
    'hint fills selected empty cell',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.hint());
    },
    verify: (bloc) {
      expect(bloc.state.status, SudokuStatus.navigating);
      expect(bloc.state.grid[1], 2);
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'reset clears player cells and keeps startedAt',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      final started = bloc.state.startedAt;
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.notesModeToggled());
      bloc.add(const SudokuEvent.digitTapped(3));
      bloc.add(const SudokuEvent.reset());
      await bloc.stream.firstWhere(
        (s) => s.notes.every((n) => n.isEmpty) && !s.notesMode,
      );
      expect(bloc.state.startedAt, started);
      expect(bloc.state.grid[1], 0);
      expect(bloc.state.notesMode, isFalse);
    },
  );
}
