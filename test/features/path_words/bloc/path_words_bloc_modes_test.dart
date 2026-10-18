import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/play_mode_hints.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/path_words/bloc/path_words_bloc.dart';
import 'package:winklo/features/path_words/bloc/path_words_event.dart';
import 'package:winklo/features/path_words/bloc/path_words_state.dart';
import 'package:winklo/features/results/results_args.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockGenerateDailyPathWords extends Mock
    implements GenerateDailyPathWords {}

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

PathWordsPuzzle _tinyPuzzle(String id) => PathWordsPuzzle(
  id: id,
  day: DateTime(2026, 10, 12),
  size: 2,
  letters: const ['a', 'b', 'c', 'd'],
  targets: const [
    PathWordsTarget(
      id: 't0',
      word: 'ab',
      start: Cell(0, 0),
      path: [Cell(0, 0), Cell(0, 1)],
      colorIndex: 0,
    ),
    PathWordsTarget(
      id: 't1',
      word: 'cd',
      start: Cell(1, 0),
      path: [Cell(1, 0), Cell(1, 1)],
      colorIndex: 1,
    ),
  ],
);

void main() {
  final archiveDay = DateTime(2026, 10, 12);
  const todayDraft = InProgressRun(
    gameId: GameIds.pathWords,
    playId: '20261015',
    elapsedMs: 4000,
    board: {},
  );

  late _MockGenerateDailyPathWords generateDaily;
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

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    generateDaily = _MockGenerateDailyPathWords();
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
    drafts = _MemoryInProgressRuns()..runs['path_words_20261015'] = todayDraft;
    now = DateTime(2026, 10, 15, 9);
    when(
      () => generateDaily(
        day: any(named: 'day'),
        period: any(named: 'period'),
      ),
    ).thenAnswer((_) async => _tinyPuzzle('path_words_20261012'));
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
    expect(drafts.touched, isNot(contains('path_words_20261015')));
    expect(drafts.runs['path_words_20261015'], same(todayDraft));
    for (final key in prefs.getKeys()) {
      expect(key.startsWith('best_time_path_words_'), isFalse, reason: key);
      expect(key.startsWith('best_pts_path_words_'), isFalse, reason: key);
      expect(key, isNot('hints_used_path_words_20261015'));
    }
  }

  PathWordsBloc buildBloc(PlayMode mode, {int Function()? newSeed}) {
    return PathWordsBloc(
      mode: mode,
      modeRecords: records,
      generateDailyPathWords: generateDaily,
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
      practiceWords: () async => const ['unused'],
      practicePuzzle: (seed, words) => _tinyPuzzle('practice_$seed'),
      newPracticeSeed: newSeed,
    );
  }

  Future<PathWordsState> ready(PathWordsBloc bloc) => bloc.stream.firstWhere(
    (s) =>
        s.status == PathWordsStatus.ready || s.status == PathWordsStatus.failed,
  );

  Future<void> trace(PathWordsBloc bloc, List<Cell> path) async {
    bloc.add(PathWordsEvent.pointerDown(path.first));
    for (final cell in path.skip(1)) {
      bloc.add(PathWordsEvent.pointerEnter(cell));
    }
    bloc.add(const PathWordsEvent.pointerUp());
    await Future<void>.delayed(Duration.zero);
  }

  /// The first state matching [test], the current one included.
  Future<PathWordsState> until(
    PathWordsBloc bloc,
    bool Function(PathWordsState s) test,
  ) {
    if (test(bloc.state)) return Future.value(bloc.state);
    return bloc.stream.firstWhere(test);
  }

  Future<PathWordsState> solve(PathWordsBloc bloc) async {
    final done = bloc.stream.firstWhere(
      (s) => s.status == PathWordsStatus.navigating,
    );
    await trace(bloc, const [Cell(0, 0), Cell(0, 1)]);
    await trace(bloc, const [Cell(1, 0), Cell(1, 1)]);
    return done;
  }

  group('archive', () {
    test('a clear never submits a score, leaderboard time, streak, daily '
        'best or daily hint', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.status, PathWordsStatus.ready);
      verify(
        () => generateDaily(day: archiveDay, period: PlayPeriod.daily),
      ).called(1);
      bloc.add(const PathWordsEvent.hint());
      await until(bloc, (s) => s.usedHintsThisRun);
      now = now.add(const Duration(seconds: 64));
      final done = await solve(bloc);
      expectNoDailyState();
      // 64s played plus the hint's 10s.
      expect(records.bestTimeSeconds('archive_path_words_20261012'), 74);
      final args = done.resultsExtra!;
      expect(args.hintPenaltySeconds, 10);
      expect(args.local!.kind, LocalResultKind.archive);
      expect(args.local!.label, 'Archive · 12 Oct');
      expect(args.currentStreak, isNull);
      expect(args.leaderboardProof, isNull);
      expect(args.usedHints, isTrue);
      await bloc.close();
    });

    test('counts archive hints per run and charges them, never the daily '
        'count', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.hintsUsed, 0);
      bloc.add(const PathWordsEvent.hint());
      final after = await until(bloc, (s) => s.hintsUsed == 1);
      expect(after.elapsedMs, 10000);
      expect(records.hintsUsed(GameIds.pathWords, 'archive_20261012'), 1);
      verifyZeroInteractions(dailyHints);
      await bloc.close();
    });

    test('a cleared day plays again instead of locking', () async {
      when(() => getBestTimeSeconds(any())).thenReturn(30);
      when(() => getBestPoints(any())).thenReturn(900);
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const PathWordsEvent.started());
      expect((await ready(bloc)).status, PathWordsStatus.ready);
      await bloc.close();
    });

    test('resume after midnight keeps the archive day', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      bloc.add(const PathWordsEvent.pauseRun());
      await until(bloc, (s) => s.resumedAt == null);
      now = DateTime(2026, 10, 19, 8);
      bloc.add(const PathWordsEvent.resumeRun());
      await until(bloc, (s) => s.resumedAt != null);
      expect(bloc.state.day, archiveDay);
      verify(
        () => generateDaily(day: archiveDay, period: PlayPeriod.daily),
      ).called(1);
      verifyNoMoreInteractions(generateDaily);
      await bloc.close();
    });

    test('its draft lives under its own run id and resumes', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      await trace(bloc, const [Cell(0, 0), Cell(0, 1)]);
      await until(bloc, (s) => s.completedTargetIds.isNotEmpty);
      expect(drafts.runs['path_words_archive_20261012'], isNotNull);
      await bloc.close();

      final again = buildBloc(PlayMode.archive(archiveDay));
      again.add(const PathWordsEvent.started());
      final resumed = await ready(again);
      expect(resumed.completedTargetIds, {'t0'});
      expectNoDailyState();
      await again.close();
    });
  });

  group('practice', () {
    test(
      'a clear never touches daily state and records the practice best',
      () async {
        final bloc = buildBloc(PlayMode.practice, newSeed: () => 5);
        bloc.add(const PathWordsEvent.started());
        final state = await ready(bloc);
        expect(state.puzzle!.id, 'practice_5');
        verifyZeroInteractions(generateDaily);
        now = now.add(const Duration(seconds: 33));
        final done = await solve(bloc);
        expectNoDailyState();
        expect(records.bestTimeSeconds('practice_path_words'), 33);
        expect(done.resultsExtra!.local!.kind, LocalResultKind.practice);
        expect(
          done.resultsExtra!.local!.againLocation,
          '/path-words?mode=practice',
        );
        await bloc.close();
      },
    );

    test('hints are free', () async {
      final bloc = buildBloc(PlayMode.practice, newSeed: () => 5);
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      bloc.add(const PathWordsEvent.hint());
      final after = await until(bloc, (s) => s.hintsUsed == 1);
      expect(after.elapsedMs, 0);
      verifyZeroInteractions(dailyHints);
      await bloc.close();
    });

    test(
      'resumes its board from the stored seed; New board replaces it',
      () async {
        var seed = 8;
        final bloc = buildBloc(PlayMode.practice, newSeed: () => seed);
        bloc.add(const PathWordsEvent.started());
        await ready(bloc);
        await trace(bloc, const [Cell(0, 0), Cell(0, 1)]);
        await until(bloc, (s) => s.completedTargetIds.isNotEmpty);
        await bloc.close();

        seed = 9;
        final again = buildBloc(PlayMode.practice, newSeed: () => seed);
        again.add(const PathWordsEvent.started());
        final resumed = await ready(again);
        expect(resumed.puzzle!.id, 'practice_8');
        expect(resumed.completedTargetIds, {'t0'});

        again.add(const PathWordsEvent.newBoard());
        final fresh = await again.stream.firstWhere(
          (s) =>
              s.status == PathWordsStatus.ready && s.puzzle?.id == 'practice_9',
        );
        expect(fresh.completedTargetIds, isEmpty);
        expect(fresh.elapsedMs, 0);
        expectNoDailyState();
        await again.close();
      },
    );
  });
}
