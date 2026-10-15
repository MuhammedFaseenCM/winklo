import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/sudoku_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/play_mode_hints.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/sudoku/sudoku_generator.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_bloc.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_event.dart';
import 'package:winklo/features/sudoku/bloc/sudoku_state.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockHintQuota extends Mock implements HintQuotaRepository {}

class _MemoryInProgressRuns implements InProgressRunRepository {
  final Map<String, InProgressRun> runs = {};
  final List<String> touched = [];
  String _key(String gameId, String playId) => '${gameId}_$playId';
  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async {
    touched.add(_key(gameId, playId));
    return runs[_key(gameId, playId)];
  }

  @override
  Future<void> save(InProgressRun run) async {
    touched.add(_key(run.gameId, run.playId));
    runs[_key(run.gameId, run.playId)] = run;
  }

  @override
  Future<void> clear({required String gameId, required String playId}) async {
    touched.add(_key(gameId, playId));
    runs.remove(_key(gameId, playId));
  }
}

/// A practice board with two cells open (indices 0 and 7).
SudokuPuzzle _twoOpen(String id) {
  final full = SudokuGenerator.cannedSolution;
  final given = List<int>.from(full)
    ..[0] = 0
    ..[7] = 0;
  return SudokuPuzzle(
    id: id,
    dateId: '',
    given: given,
    solution: List<int>.from(full),
    difficulty: SudokuGenerator.difficultyForDate(DateTime(2026, 1, 3)),
  );
}

void main() {
  final archiveDay = DateTime(2026, 10, 12);
  const todayDraft = InProgressRun(
    gameId: GameIds.sudoku,
    playId: '20261015',
    elapsedMs: 4000,
    board: {},
  );

  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockIsNewPersonalBest isNewPersonalBest;
  late _MockHintQuota dailyHints;
  late MockAnalyticsRepository analytics;
  late SharedPreferences prefs;
  late PlayModeRecordRepositoryImpl records;
  late HintQuotaForMode hintsForMode;
  late _MemoryInProgressRuns drafts;
  late DateTime now;
  late List<DateTime> fetched;

  setUp(() async {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    isNewPersonalBest = _MockIsNewPersonalBest();
    dailyHints = _MockHintQuota();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    records = PlayModeRecordRepositoryImpl(prefs);
    hintsForMode = HintQuotaForMode(
      daily: dailyHints,
      archive: ArchiveHintQuotaRepositoryImpl(records),
      practice: UnlimitedHintQuotaRepositoryImpl(),
    );
    drafts = _MemoryInProgressRuns()..runs['sudoku_20261015'] = todayDraft;
    now = DateTime(2026, 10, 15, 9);
    fetched = [];
  });

  void expectNoDailyState() {
    verifyNever(
      () => submitScore(
        modeKey: any(named: 'modeKey'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        board: any(named: 'board'),
        bonusWords: any(named: 'bonusWords'),
      ),
    );
    verifyNever(
      () => submitLeaderboardTime(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
        dayId: any(named: 'dayId'),
        playId: any(named: 'playId'),
        proof: any(named: 'proof'),
      ),
    );
    verifyNever(
      () => recordDailyClear(
        gameId: any(named: 'gameId'),
        dateId: any(named: 'dateId'),
      ),
    );
    verifyZeroInteractions(isNewPersonalBest);
    verifyZeroInteractions(getBestPoints);
    verifyZeroInteractions(getBestTimeSeconds);
    verifyZeroInteractions(dailyHints);
    expect(drafts.touched, isNot(contains('sudoku_20261015')));
    expect(drafts.runs['sudoku_20261015'], same(todayDraft));
    for (final key in prefs.getKeys()) {
      expect(key.startsWith('best_time_sudoku_'), isFalse, reason: key);
      expect(key.startsWith('best_pts_sudoku_'), isFalse, reason: key);
      expect(key, isNot('hints_used_sudoku_20261015'));
    }
  }

  SudokuBloc buildBloc(PlayMode mode, {int Function()? newSeed}) {
    return SudokuBloc(
      mode: mode,
      modeRecords: records,
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      isNewPersonalBest: isNewPersonalBest,
      analytics: analytics,
      hintQuota: hintsForMode(mode),
      inProgressRuns: drafts,
      now: () => now,
      wait: (_) async {},
      generatePuzzle: ({required day}) {
        fetched.add(day);
        return _twoOpen('sudoku_20261012');
      },
      practicePuzzle: (seed) => _twoOpen('practice_$seed'),
      newPracticeSeed: newSeed,
    );
  }

  Future<SudokuState> until(SudokuBloc bloc, bool Function(SudokuState) t) {
    if (t(bloc.state)) return Future.value(bloc.state);
    return bloc.stream.firstWhere(t);
  }

  Future<SudokuState> ready(SudokuBloc bloc) => until(
    bloc,
    (s) => s.status == SudokuStatus.ready || s.status == SudokuStatus.failed,
  );

  Future<SudokuState> solve(SudokuBloc bloc) async {
    final done = bloc.stream.firstWhere(
      (s) => s.status == SudokuStatus.navigating,
    );
    final solution = bloc.state.puzzle!.solution;
    bloc.add(const SudokuEvent.cellSelected(Cell(0, 0)));
    bloc.add(SudokuEvent.digitTapped(solution[0]));
    await until(bloc, (s) => s.grid[0] != 0);
    bloc.add(const SudokuEvent.cellSelected(Cell(1, 1)));
    bloc.add(SudokuEvent.digitTapped(solution[7]));
    return done;
  }

  group('archive', () {
    test('a clear never submits a score, leaderboard time, streak, daily '
        'best or daily hint', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const SudokuEvent.started());
      expect((await ready(bloc)).status, SudokuStatus.ready);
      expect(fetched, [archiveDay]);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 0)));
      bloc.add(const SudokuEvent.hint());
      await until(bloc, (s) => s.usedHintsThisRun);
      now = now.add(const Duration(seconds: 81));
      final done = await solve(bloc);
      expectNoDailyState();
      expect(records.bestTimeSeconds('archive_sudoku_20261012'), 81);
      final args = done.resultsExtra!;
      expect(args.local!.kind, LocalResultKind.archive);
      expect(args.local!.label, 'Archive · 12 Oct');
      expect(args.currentStreak, isNull);
      expect(args.leaderboardProof, isNull);
      await bloc.close();
    });

    test('spends 3 archive hints per run, never the daily quota', () async {
      await records.setHintsUsed(GameIds.sudoku, 'archive_20261012', 3);
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const SudokuEvent.started());
      final state = await ready(bloc);
      // A fresh run starts with a full set.
      expect(state.hintsRemaining, 3);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 0)));
      bloc.add(const SudokuEvent.hint());
      final after = await until(bloc, (s) => s.hintsRemaining == 2);
      expect(after.hintsRemaining, 2);
      expect(records.hintsUsed(GameIds.sudoku, 'archive_20261012'), 1);
      verifyZeroInteractions(dailyHints);
      await bloc.close();
    });

    test('a cleared day plays again instead of locking', () async {
      when(() => getBestTimeSeconds(any())).thenReturn(30);
      when(() => getBestPoints(any())).thenReturn(900);
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const SudokuEvent.started());
      expect((await ready(bloc)).status, SudokuStatus.ready);
      await bloc.close();
    });

    test('resume after midnight keeps the archive day', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const SudokuEvent.started());
      await ready(bloc);
      bloc.add(const SudokuEvent.pauseRun());
      await until(bloc, (s) => s.resumedAt == null);
      now = DateTime(2026, 10, 20, 7);
      bloc.add(const SudokuEvent.resumeRun());
      await until(bloc, (s) => s.resumedAt != null);
      expect(bloc.state.day, archiveDay);
      expect(fetched, [archiveDay]);
      await bloc.close();
    });

    test('its draft lives under its own run id and resumes', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const SudokuEvent.started());
      final state = await ready(bloc);
      bloc.add(const SudokuEvent.cellSelected(Cell(0, 0)));
      bloc.add(SudokuEvent.digitTapped(state.puzzle!.solution[0]));
      await until(bloc, (s) => s.grid[0] != 0);
      expect(drafts.runs['sudoku_archive_20261012'], isNotNull);
      await bloc.close();

      final again = buildBloc(PlayMode.archive(archiveDay));
      again.add(const SudokuEvent.started());
      final resumed = await ready(again);
      expect(resumed.grid[0], state.puzzle!.solution[0]);
      expectNoDailyState();
      await again.close();
    });
  });

  group('practice', () {
    test(
      'a clear never touches daily state and records the practice best',
      () async {
        final bloc = buildBloc(PlayMode.practice, newSeed: () => 4);
        bloc.add(const SudokuEvent.started());
        final state = await ready(bloc);
        expect(state.puzzle!.id, 'practice_4');
        expect(fetched, isEmpty);
        expect(state.hintsRemaining, greaterThan(100));
        now = now.add(const Duration(seconds: 52));
        final done = await solve(bloc);
        expectNoDailyState();
        expect(records.bestTimeSeconds('practice_sudoku'), 52);
        expect(
          done.resultsExtra!.local!.againLocation,
          '/sudoku?mode=practice',
        );
        await bloc.close();
      },
    );

    test(
      'resumes its board from the stored seed; New board replaces it',
      () async {
        var seed = 31;
        final bloc = buildBloc(PlayMode.practice, newSeed: () => seed);
        bloc.add(const SudokuEvent.started());
        final state = await ready(bloc);
        bloc.add(const SudokuEvent.cellSelected(Cell(0, 0)));
        bloc.add(SudokuEvent.digitTapped(state.puzzle!.solution[0]));
        await until(bloc, (s) => s.grid[0] != 0);
        await bloc.close();

        seed = 32;
        final again = buildBloc(PlayMode.practice, newSeed: () => seed);
        again.add(const SudokuEvent.started());
        final resumed = await ready(again);
        expect(resumed.puzzle!.id, 'practice_31');
        expect(resumed.grid[0], state.puzzle!.solution[0]);

        again.add(const SudokuEvent.newBoard());
        final fresh = await again.stream.firstWhere(
          (s) =>
              s.status == SudokuStatus.ready && s.puzzle?.id == 'practice_32',
        );
        expect(fresh.grid[0], 0);
        expect(fresh.elapsedMs, 0);
        expectNoDailyState();
        await again.close();
      },
    );
  });
}
