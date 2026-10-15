import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/play_mode_record_repository_impl.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_board.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/zip/bloc/zip_bloc.dart';
import 'package:winklo/features/zip/bloc/zip_event.dart';
import 'package:winklo/features/zip/bloc/zip_state.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockGetClearBoard extends Mock implements GetClearBoard {}

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

void main() {
  final archiveDay = DateTime(2026, 10, 12);
  final today = DateTime(2026, 10, 15, 9);
  final todayDraft = InProgressRun(
    gameId: GameIds.zip,
    playId: '20261015',
    elapsedMs: 4000,
    board: const {'path': []},
  );

  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockIsNewPersonalBest isNewPersonalBest;
  late _MockGetClearBoard getClearBoard;
  late MockAnalyticsRepository analytics;
  late SharedPreferences prefs;
  late PlayModeRecordRepositoryImpl records;
  late _MemoryInProgressRuns drafts;
  late DateTime now;
  late List<DateTime> fetchedDays;

  setUp(() async {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    isNewPersonalBest = _MockIsNewPersonalBest();
    getClearBoard = _MockGetClearBoard();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    records = PlayModeRecordRepositoryImpl(prefs);
    drafts = _MemoryInProgressRuns()..runs['zip_20261015'] = todayDraft;
    now = today;
    fetchedDays = [];
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
    verifyNever(
      () => isNewPersonalBest(
        gameId: any(named: 'gameId'),
        playId: any(named: 'playId'),
        timeSeconds: any(named: 'timeSeconds'),
      ),
    );
    verifyZeroInteractions(getBestPoints);
    verifyZeroInteractions(getBestTimeSeconds);
    verifyZeroInteractions(getClearBoard);
    // Today's draft is neither read nor rewritten.
    expect(drafts.touched, isNot(contains('zip_20261015')));
    expect(drafts.runs['zip_20261015'], same(todayDraft));
    for (final key in prefs.getKeys()) {
      expect(key.contains('zip_daily_'), isFalse, reason: key);
      expect(key, isNot('hints_used_zip_20261015'));
    }
  }

  ZipBloc buildBloc(PlayMode mode, {int Function()? newSeed}) {
    return ZipBloc(
      mode: mode,
      modeRecords: records,
      inProgressRuns: drafts,
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      isNewPersonalBest: isNewPersonalBest,
      getClearBoard: getClearBoard,
      analytics: analytics,
      clockNow: () => now,
      wait: (_) async {},
      newPracticeSeed: newSeed,
      fetchDailyLevel: (date, {period = PlayPeriod.daily}) async {
        fetchedDays.add(date);
        return DailyPuzzleGenerator.forDate(date, period: period);
      },
    );
  }

  Future<ZipState> ready(ZipBloc bloc) => bloc.stream.firstWhere(
    (s) => s.status == ZipStatus.ready || s.status == ZipStatus.failed,
  );

  Future<ZipState> finish(ZipBloc bloc) async {
    bloc.add(ZipEvent.pathChanged(path: bloc.state.level.solution));
    bloc.add(const ZipEvent.completed());
    return bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);
  }

  group('archive', () {
    test('a clear never submits a score, leaderboard time, streak or daily '
        'best, and never reads the daily lock', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      final started = await ready(bloc);
      expect(started.status, ZipStatus.ready);
      expect(fetchedDays.single, archiveDay);
      expect(started.level.id, 'daily_20261012');
      now = now.add(const Duration(seconds: 75));
      await finish(bloc);
      expectNoDailyState();
      await bloc.close();
    });

    test('a clear records the archive best and shows it on Results', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      now = now.add(const Duration(seconds: 75));
      final done = await finish(bloc);
      expect(records.bestTimeSeconds('archive_zip_20261012'), 75);
      final args = done.resultsExtra!;
      expect(args.timeSeconds, 75);
      expect(args.currentStreak, isNull);
      expect(args.leaderboardProof, isNull);
      expect(args.replayDaily, isFalse);
      expect(args.local!.kind, LocalResultKind.archive);
      expect(args.local!.label, 'Archive · 12 Oct');
      expect(args.local!.bestSeconds, 75);
      verify(
        () => analytics.logGameCompleted(
          gameId: GameIds.zip,
          points: any(named: 'points'),
          timeSeconds: 75,
          streak: null,
          dayId: 'archive_20261012',
          usedHints: false,
        ),
      ).called(1);
      await bloc.close();
    });

    test('the clock runs for an archive day', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      now = now.add(const Duration(seconds: 42));
      final done = await finish(bloc);
      expect(done.timeSeconds, 42);
      await bloc.close();
    });

    test('a slower replay keeps the best and is not a new best', () async {
      await records.recordTime('archive_zip_20261012', 30);
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      now = now.add(const Duration(seconds: 50));
      final done = await finish(bloc);
      expect(done.resultsExtra!.improved, isFalse);
      expect(done.resultsExtra!.local!.bestSeconds, 30);
      await bloc.close();
    });

    test('a cleared archive day plays again instead of locking', () async {
      await records.recordTime('archive_zip_20261012', 30);
      when(() => getBestTimeSeconds(any())).thenReturn(20);
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      final state = await ready(bloc);
      expect(state.status, ZipStatus.ready);
      expect(bloc.playId, 'archive_20261012');
      await bloc.close();
    });

    test('its draft lives under its own run id and resumes', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      final state = await ready(bloc);
      bloc.add(ZipEvent.pathChanged(path: state.level.solution.sublist(0, 3)));
      await bloc.stream.firstWhere((s) => s.path.length == 3);
      expect(drafts.runs['zip_archive_20261012'], isNotNull);
      await bloc.close();

      final again = buildBloc(PlayMode.archive(archiveDay));
      again.add(const ZipEvent.started());
      final resumed = await ready(again);
      expect(resumed.path.length, 3);
      expectNoDailyState();
      await again.close();
    });

    test('a fresh run gets 3 hints again', () async {
      await records.setHintsUsed(GameIds.zip, 'archive_20261012', 3);
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      expect(records.hintsUsed(GameIds.zip, 'archive_20261012'), 0);
      await bloc.close();
    });

    test('resume after midnight keeps the archive day', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      final state = await ready(bloc);
      bloc.add(ZipEvent.pathChanged(path: state.level.solution.sublist(0, 2)));
      bloc.add(const ZipEvent.pauseRun());
      await bloc.stream.firstWhere((s) => !s.isClockRunning);
      now = DateTime(2026, 10, 18, 9);
      bloc.add(const ZipEvent.resumeRun());
      await bloc.stream.firstWhere((s) => s.isClockRunning);
      expect(bloc.state.level.id, 'daily_20261012');
      expect(fetchedDays, [archiveDay]);
      await bloc.close();
    });
  });

  group('practice', () {
    test(
      'a clear never touches daily state and records the practice best',
      () async {
        final bloc = buildBloc(PlayMode.practice, newSeed: () => 7);
        bloc.add(const ZipEvent.started());
        final state = await ready(bloc);
        expect(fetchedDays, isEmpty);
        expect(state.level.id, 'practice_7');
        expect(state.level.size, 8);
        now = now.add(const Duration(seconds: 90));
        final done = await finish(bloc);
        expectNoDailyState();
        expect(records.bestTimeSeconds('practice_zip'), 90);
        expect(done.resultsExtra!.local!.kind, LocalResultKind.practice);
        expect(done.resultsExtra!.local!.againLocation, '/zip?mode=practice');
        expect(drafts.runs['zip_practice'], isNull);
        await bloc.close();
      },
    );

    test('resumes its draft board from the stored seed', () async {
      var seed = 11;
      final bloc = buildBloc(PlayMode.practice, newSeed: () => seed);
      bloc.add(const ZipEvent.started());
      final state = await ready(bloc);
      bloc.add(ZipEvent.pathChanged(path: state.level.solution.sublist(0, 4)));
      await bloc.stream.firstWhere((s) => s.path.length == 4);
      await bloc.close();

      seed = 12;
      final again = buildBloc(PlayMode.practice, newSeed: () => seed);
      again.add(const ZipEvent.started());
      final resumed = await ready(again);
      expect(resumed.level.id, 'practice_11');
      expect(resumed.path.length, 4);
      await again.close();
    });

    test('New board replaces the board and drops the draft', () async {
      var seed = 21;
      final bloc = buildBloc(PlayMode.practice, newSeed: () => seed);
      bloc.add(const ZipEvent.started());
      final state = await ready(bloc);
      bloc.add(ZipEvent.pathChanged(path: state.level.solution.sublist(0, 4)));
      await bloc.stream.firstWhere((s) => s.path.length == 4);
      seed = 22;
      bloc.add(const ZipEvent.newBoard());
      final fresh = await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.ready && s.level.id == 'practice_22',
      );
      expect(fresh.path, isEmpty);
      expect(fresh.elapsedMs, 0);
      expect(fresh.usedHintsThisRun, isFalse);
      expectNoDailyState();
      await bloc.close();
    });

    test('New board does nothing outside practice', () async {
      final bloc = buildBloc(PlayMode.archive(archiveDay));
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      bloc.add(const ZipEvent.newBoard());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.level.id, 'daily_20261012');
      expect(fetchedDays.length, 1);
      await bloc.close();
    });
  });
}
