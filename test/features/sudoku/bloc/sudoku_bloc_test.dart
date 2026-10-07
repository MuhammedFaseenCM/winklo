import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/sudoku_difficulty.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
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

class _MockSfx extends Mock implements SfxService {}

class _FakeHintQuota implements HintQuotaRepository {
  _FakeHintQuota(this._remaining);

  int _remaining;

  @override
  int remaining(String gameId) => _remaining;

  @override
  Future<int> tryConsume(String gameId) async {
    if (_remaining <= 0) return 0;
    _remaining--;
    return _remaining;
  }

  @override
  int usedFor(String gameId, String playId) => 0;

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}

class _MemoryInProgressRuns implements InProgressRunRepository {
  final Map<String, InProgressRun> runs = {};

  String _key(String gameId, String playId) => '${gameId}_$playId';

  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async => runs[_key(gameId, playId)];

  @override
  Future<void> save(InProgressRun run) async {
    runs[_key(run.gameId, run.playId)] = run;
  }

  @override
  Future<void> clear({required String gameId, required String playId}) async {
    runs.remove(_key(gameId, playId));
  }
}

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

SudokuPuzzle _noCoachPuzzle({required DateTime day}) {
  return SudokuPuzzle(
    id: 'no_coach',
    dateId: '20260927',
    given: List<int>.filled(36, 0),
    solution: List<int>.filled(36, 1),
    difficulty: SudokuDifficulty.easy,
  );
}

/// Extra empties in the same row, column, and box as index 1 so placing
/// one correct digit there does not complete any unit.
SudokuPuzzle _noUnitCompletePuzzle({required DateTime day}) {
  final puzzle = _almostSolvedPuzzle(day: day);
  final given = List<int>.from(puzzle.given);
  given[2] = 0; // (0,2) same row + box
  given[7] = 0; // (1,1) same column + box
  return SudokuPuzzle(
    id: puzzle.id,
    dateId: puzzle.dateId,
    given: given,
    solution: puzzle.solution,
    difficulty: puzzle.difficulty,
  );
}

SudokuPuzzle _twoEmptyPuzzle({required DateTime day}) {
  final puzzle = _almostSolvedPuzzle(day: day);
  final given = List<int>.from(puzzle.given);
  given[34] = 0; // second empty — solution digit 1
  return SudokuPuzzle(
    id: puzzle.id,
    dateId: puzzle.dateId,
    given: given,
    solution: puzzle.solution,
    difficulty: puzzle.difficulty,
  );
}

void main() {
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockAnalyticsRepository analytics;
  late _FakeHintQuota hintQuota;
  late _MemoryInProgressRuns inProgressRuns;
  final day = DateTime(2026, 9, 27);

  SudokuBloc buildBloc({
    SudokuPuzzle Function({required DateTime day})? generatePuzzle,
    DateTime Function()? now,
    _FakeHintQuota? quota,
    _MemoryInProgressRuns? drafts,
    SfxService? sfx,
  }) {
    return SudokuBloc(
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      analytics: analytics,
      hintQuota: quota ?? hintQuota,
      inProgressRuns: drafts ?? inProgressRuns,
      generatePuzzle:
          generatePuzzle ??
          ({required DateTime day}) => _almostSolvedPuzzle(day: day),
      now: now ?? () => day,
      wait: (_) async {},
      celebrationDuration: Duration.zero,
      sfx: sfx,
    );
  }

  _MockSfx stubSfx() {
    final sfx = _MockSfx();
    when(() => sfx.play(any())).thenAnswer((_) async {});
    return sfx;
  }

  setUp(() {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    analytics = _MockAnalyticsRepository();
    hintQuota = _FakeHintQuota(3);
    inProgressRuns = _MemoryInProgressRuns();
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    when(
      () => submitScore(
        modeKey: any(named: 'modeKey'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => submitLeaderboardTime(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
        dayId: any(named: 'dayId'),
        playId: any(named: 'playId'),
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
    registerFallbackValue(SfxId.tap);
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
          .having((s) => s.hintsRemaining, 'hintsRemaining', 3)
          .having((s) => s.resumedAt, 'resumedAt', isNotNull)
          .having((s) => s.elapsedMs, 'elapsedMs', 0),
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
    'wrong digit is accepted and marks error when unit is full',
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
          .having((s) => s.grid[1], 'grid', 3)
          .having((s) => s.errorIndices, 'errors', equals({1}))
          .having((s) => s.hadMistakesThisRun, 'hadMistakesThisRun', isTrue),
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
          usedHints: false,
          hadMistakes: false,
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.sudoku,
          timeSeconds: 10,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 1,
          dayId: '2026-09-27',
          playId: '20260927',
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
    'win after a mistake passes hadMistakes and the puzzle day',
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
      bloc.add(const SudokuEvent.digitTapped(3));
      bloc.add(const SudokuEvent.digitTapped(2));
    },
    verify: (bloc) {
      expect(bloc.state.status, SudokuStatus.navigating);
      verify(
        () => submitScore(
          modeKey: any(named: 'modeKey', that: startsWith('sudoku_')),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: false,
          hadMistakes: true,
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.sudoku,
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: false,
          hadMistakes: true,
          currentStreak: any(named: 'currentStreak'),
          dayId: '2026-09-27',
          playId: '20260927',
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
    'hint shows coach without filling grid',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.hint());
    },
    skip: 2,
    expect: () => [
      isA<SudokuState>().having((s) => s.selectedIndex, 'selected', 1),
      isA<SudokuState>()
          .having((s) => s.grid[1], 'grid unchanged', 0)
          .having((s) => s.activeCoachHint?.targetIndex, 'target', 1)
          .having((s) => s.activeCoachHint?.digit, 'digit', 2)
          .having((s) => s.hintsRemaining, 'remaining', 2)
          .having((s) => s.usedHintsThisRun, 'usedHintsThisRun', isTrue)
          .having((s) => s.hintFlashIndex, 'no flash', isNull),
    ],
    verify: (_) {
      verify(
        () => analytics.logHintUsed(gameId: GameIds.sudoku, hintsRemaining: 2),
      ).called(1);
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'hint with no teachable move shows banner without consuming quota',
    build: () => buildBloc(
      generatePuzzle: ({required DateTime day}) => _noCoachPuzzle(day: day),
    ),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.hint());
    },
    skip: 2,
    expect: () => [
      isA<SudokuState>()
          .having((s) => s.showNoSimpleHint, 'banner', isTrue)
          .having((s) => s.activeCoachHint, 'coach', isNull)
          .having((s) => s.hintsRemaining, 'remaining', 3),
    ],
    verify: (_) {
      verifyNever(
        () => analytics.logHintUsed(
          gameId: any(named: 'gameId'),
          hintsRemaining: any(named: 'hintsRemaining'),
        ),
      );
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'reset after hint consume keeps depleted quota',
    build: () => buildBloc(quota: _FakeHintQuota(3)),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.hint());
      await bloc.stream.firstWhere((s) => s.hintsRemaining == 2);
      bloc.add(const SudokuEvent.reset());
    },
    verify: (bloc) {
      expect(bloc.state.hintsRemaining, 2);
      expect(bloc.state.activeCoachHint, isNull);
      expect(bloc.state.grid[1], 0);
      expect(bloc.state.usedHintsThisRun, isFalse);
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'dismissHint clears coach and banner',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.hint());
      await bloc.stream.firstWhere((s) => s.activeCoachHint != null);
      bloc.add(const SudokuEvent.dismissHint());
    },
    skip: 2,
    expect: () => [
      isA<SudokuState>().having((s) => s.activeCoachHint, 'coach', isNotNull),
      isA<SudokuState>()
          .having((s) => s.activeCoachHint, 'coach cleared', isNull)
          .having((s) => s.showNoSimpleHint, 'banner', isFalse),
    ],
  );

  blocTest<SudokuBloc, SudokuState>(
    'placing hinted digit clears active coach',
    build: () => buildBloc(
      generatePuzzle: ({required DateTime day}) => _twoEmptyPuzzle(day: day),
    ),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.hint());
      await bloc.stream.firstWhere((s) => s.activeCoachHint != null);
      bloc.add(const SudokuEvent.digitTapped(2));
      await bloc.stream.firstWhere((s) => s.activeCoachHint == null);
    },
    verify: (bloc) {
      expect(bloc.state.grid[1], 2);
      expect(bloc.state.activeCoachHint, isNull);
      expect(bloc.state.status, SudokuStatus.ready);
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'reset clears player cells and keeps elapsed clock',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      final resumedAt = bloc.state.resumedAt;
      final elapsedMs = bloc.state.elapsedMs;
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.notesModeToggled());
      bloc.add(const SudokuEvent.digitTapped(3));
      bloc.add(const SudokuEvent.reset());
      await bloc.stream.firstWhere(
        (s) => s.notes.every((n) => n.isEmpty) && !s.notesMode,
      );
      expect(bloc.state.resumedAt, resumedAt);
      expect(bloc.state.elapsedMs, elapsedMs);
      expect(bloc.state.grid[1], 0);
      expect(bloc.state.notesMode, isFalse);
    },
  );

  test('pause then resume does not count away time', () async {
    var now = day;
    final bloc = buildBloc(now: () => now);
    bloc.add(SudokuEvent.started(date: day));
    await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);

    now = day.add(const Duration(seconds: 5));
    bloc.add(const SudokuEvent.pauseRun());
    await bloc.stream.firstWhere((s) => !s.isClockRunning);
    expect(bloc.state.elapsedMs, 5000);

    now = day.add(const Duration(minutes: 10));
    bloc.add(const SudokuEvent.resumeRun());
    await bloc.stream.firstWhere((s) => s.isClockRunning);

    now = day.add(const Duration(minutes: 10, seconds: 3));
    expect(bloc.state.liveElapsedSeconds(now), 8);
    await bloc.close();
  });

  test(
    'resume after day rolls over starts next day and clears stale draft',
    () async {
      var now = day;
      final drafts = _MemoryInProgressRuns();
      final bloc = buildBloc(now: () => now, drafts: drafts);
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);

      now = day.add(const Duration(seconds: 5));
      bloc.add(const SudokuEvent.pauseRun());
      await bloc.stream.firstWhere((s) => !s.isClockRunning);
      expect(drafts.runs['${GameIds.sudoku}_20260927'], isNotNull);
      expect(bloc.state.day, DateTime(2026, 9, 27));

      final nextDay = DateTime(2026, 9, 28);
      now = nextDay;
      bloc.add(const SudokuEvent.resumeRun());
      await bloc.stream.firstWhere(
        (s) => s.status == SudokuStatus.ready && s.day == DateTime(2026, 9, 28),
      );

      expect(bloc.state.day, DateTime(2026, 9, 28));
      expect(bloc.state.elapsedMs, 0);
      expect(drafts.runs['${GameIds.sudoku}_20260927'], isNull);
      await bloc.close();
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'restores draft grid and elapsed on start',
    build: () {
      final puzzle = _almostSolvedPuzzle(day: day);
      final grid = List<int>.from(puzzle.given);
      grid[1] = 3;
      inProgressRuns.runs['${GameIds.sudoku}_20260927'] = InProgressRun(
        gameId: GameIds.sudoku,
        playId: '20260927',
        elapsedMs: 12000,
        hadMistakesThisRun: true,
        board: {
          'grid': grid,
          'notes': List.generate(puzzle.cellCount, (_) => <int>[]),
          'notesMode': false,
        },
      );
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
          .having((s) => s.status, 'status', SudokuStatus.ready)
          .having((s) => s.grid[1], 'restored cell', 3)
          .having((s) => s.elapsedMs, 'elapsedMs', 12000)
          .having((s) => s.hadMistakesThisRun, 'hadMistakes', isTrue),
    ],
  );

  blocTest<SudokuBloc, SudokuState>(
    'selecting a cell stays silent',
    build: () => buildBloc(sfx: stubSfx()),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      await bloc.stream.firstWhere((s) => s.selectedIndex == 1);
    },
    verify: (bloc) {
      verifyNever(() => bloc.sfx!.play(SfxId.tap));
      verifyNever(() => bloc.sfx!.play(SfxId.success));
      verifyNever(() => bloc.sfx!.play(SfxId.reject));
      verifyNever(() => bloc.sfx!.play(SfxId.clear));
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'digit place that does not complete a unit stays silent',
    build: () => buildBloc(
      generatePuzzle: ({required DateTime day}) =>
          _noUnitCompletePuzzle(day: day),
      sfx: stubSfx(),
    ),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.digitTapped(2));
      await bloc.stream.firstWhere((s) => s.grid[1] == 2);
    },
    verify: (bloc) {
      expect(bloc.state.errorIndices, isEmpty);
      expect(bloc.state.status, SudokuStatus.ready);
      expect(bloc.state.celebratedUnitIds, isEmpty);
      verifyNever(() => bloc.sfx!.play(SfxId.tap));
      verifyNever(() => bloc.sfx!.play(SfxId.success));
      verifyNever(() => bloc.sfx!.play(SfxId.reject));
      verifyNever(() => bloc.sfx!.play(SfxId.clear));
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'completing a unit plays success',
    build: () => buildBloc(
      generatePuzzle: ({required DateTime day}) => _twoEmptyPuzzle(day: day),
      sfx: stubSfx(),
    ),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.digitTapped(2));
      await bloc.stream.firstWhere((s) => s.grid[1] == 2);
    },
    verify: (bloc) {
      expect(bloc.state.errorIndices, isEmpty);
      expect(bloc.state.status, SudokuStatus.ready);
      expect(bloc.state.celebratedUnitIds, isNotEmpty);
      verify(() => bloc.sfx!.play(SfxId.success)).called(1);
      verifyNever(() => bloc.sfx!.play(SfxId.tap));
      verifyNever(() => bloc.sfx!.play(SfxId.reject));
      verifyNever(() => bloc.sfx!.play(SfxId.clear));
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'erroneous digit place stays silent',
    build: () => buildBloc(sfx: stubSfx()),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.digitTapped(3));
      await bloc.stream.firstWhere((s) => s.grid[1] == 3);
    },
    verify: (bloc) {
      expect(bloc.state.errorIndices, {1});
      verifyNever(() => bloc.sfx!.play(SfxId.tap));
      verifyNever(() => bloc.sfx!.play(SfxId.reject));
      verifyNever(() => bloc.sfx!.play(SfxId.success));
      verifyNever(() => bloc.sfx!.play(SfxId.clear));
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'solving the board plays success then clear',
    build: () => buildBloc(sfx: stubSfx()),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.digitTapped(2));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.navigating);
    },
    verify: (bloc) {
      verify(() => bloc.sfx!.play(SfxId.success)).called(1);
      verify(() => bloc.sfx!.play(SfxId.clear)).called(1);
      verifyNever(() => bloc.sfx!.play(SfxId.tap));
      verifyNever(() => bloc.sfx!.play(SfxId.reject));
    },
  );

  blocTest<SudokuBloc, SudokuState>(
    'notes mode stays silent',
    build: () => buildBloc(sfx: stubSfx()),
    act: (bloc) async {
      bloc.add(SudokuEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == SudokuStatus.ready);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 1)));
      bloc.add(const SudokuEvent.notesModeToggled());
      bloc.add(const SudokuEvent.digitTapped(3));
      await bloc.stream.firstWhere((s) => s.notes[1].contains(3));
    },
    verify: (bloc) {
      verifyNever(() => bloc.sfx!.play(SfxId.tap));
      verifyNever(() => bloc.sfx!.play(SfxId.success));
      verifyNever(() => bloc.sfx!.play(SfxId.reject));
      verifyNever(() => bloc.sfx!.play(SfxId.clear));
    },
  );
}
