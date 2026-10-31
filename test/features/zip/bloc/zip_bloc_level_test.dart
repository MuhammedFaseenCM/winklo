import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_board.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/record_level_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/zip/bloc/zip_bloc.dart';
import 'package:winklo/features/zip/bloc/zip_event.dart';
import 'package:winklo/features/zip/bloc/zip_state.dart';

import '../../../helpers/level_fixtures.dart';
import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockGetClearBoard extends Mock implements GetClearBoard {}

class _Worlds implements LevelWorldRepository {
  _Worlds(this.value);
  final LevelCatalog value;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      value;
}

class _OfflineWorlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      throw const LevelsUnavailable('offline');
}

class _MemoryInProgressRuns implements InProgressRunRepository {
  final Map<String, InProgressRun> runs = {};
  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async => runs['${gameId}_$playId'];
  @override
  Future<void> save(InProgressRun run) async =>
      runs['${run.gameId}_${run.playId}'] = run;
  @override
  Future<void> clear({required String gameId, required String playId}) async =>
      runs.remove('${gameId}_$playId');
}

void main() {
  final catalog = LevelCatalog([
    levelWorld(1, 2),
    levelWorld(2, 1, theme: 'metro'),
  ]);
  late MockAnalyticsRepository analytics;
  late _MockRecordDailyClear recordDailyClear;
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockGetBestPoints getBestPoints;
  late LevelProgressRepositoryImpl progress;
  late _MemoryInProgressRuns drafts;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    recordDailyClear = _MockRecordDailyClear();
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    getBestPoints = _MockGetBestPoints();
    progress = LevelProgressRepositoryImpl(prefs, currentUid: () => 'u1');
    drafts = _MemoryInProgressRuns();
    now = DateTime(2026, 10, 31, 9);
  });

  ZipBloc build(String levelId, {LevelCatalog? from, bool gated = false}) =>
      ZipBloc(
        mode: PlayMode.level(levelId),
        levelWorlds: _Worlds(from ?? catalog),
        recordLevelClear: RecordLevelClear(progress, analytics),
        levelProgress: gated ? progress : null,
        inProgressRuns: drafts,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: _MockGetBestTimeSeconds(),
        isNewPersonalBest: _MockIsNewPersonalBest(),
        getClearBoard: _MockGetClearBoard(),
        analytics: analytics,
        hintQuota: UnlimitedHintQuotaRepositoryImpl(),
        clockNow: () => now,
        wait: (_) async {},
        fetchDailyLevel: (date, {period = const Duration(days: 1)}) =>
            throw StateError('a level run never reads a daily'),
      );

  Future<ZipState> ready(ZipBloc bloc) => bloc.stream.firstWhere(
    (s) => s.status == ZipStatus.ready || s.status == ZipStatus.failed,
  );

  Future<ZipState> finish(ZipBloc bloc) async {
    bloc.add(ZipEvent.pathChanged(path: bloc.state.level.solution));
    bloc.add(const ZipEvent.completed());
    return bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);
  }

  test(
    'a locked level fails with the locked message and keeps its draft',
    () async {
      drafts.runs['zip_level_zip_1_02'] = InProgressRun(
        gameId: 'zip',
        playId: 'level_zip_1_02',
        elapsedMs: 1000,
        board: const {'path': []},
      );
      final bloc = build('zip_1_02', gated: true);
      bloc.add(const ZipEvent.started());
      final state = await ready(bloc);
      expect(state.status, ZipStatus.failed);
      expect(state.errorMessage, 'This level is still locked.');
      expect(drafts.runs['zip_level_zip_1_02'], isNotNull);
      await bloc.close();
    },
  );

  test('the current level and cleared levels play when gated', () async {
    final first = build('zip_1_01', gated: true);
    first.add(const ZipEvent.started());
    expect((await ready(first)).status, ZipStatus.ready);
    await first.close();

    await progress.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    for (final id in ['zip_1_01', 'zip_1_02']) {
      final bloc = build(id, gated: true);
      bloc.add(const ZipEvent.started());
      expect((await ready(bloc)).status, ZipStatus.ready, reason: id);
      await bloc.close();
    }
  });

  test('a later world stays locked until the one before is cleared', () async {
    final locked = build('zip_2_01', gated: true);
    locked.add(const ZipEvent.started());
    final lockedState = await ready(locked);
    expect(lockedState.status, ZipStatus.failed);
    expect(lockedState.errorMessage, 'This level is still locked.');
    await locked.close();

    await progress.record('zip', 'zip_1_01', stars: 2, seconds: 20);
    await progress.record('zip', 'zip_1_02', stars: 2, seconds: 20);
    final open = build('zip_2_01', gated: true);
    open.add(const ZipEvent.started());
    expect((await ready(open)).status, ZipStatus.ready);
    await open.close();
  });

  test('loads the board from the catalog', () async {
    final bloc = build('zip_1_02');
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.ready);
    expect(state.level.id, 'zip_1_02');
    expect(bloc.levelSlot!.number, 2);
    expect(bloc.playId, 'level_zip_1_02');
    await bloc.close();
  });

  test(
    'a clean, fast clear earns three stars and offers the next level',
    () async {
      final bloc = build('zip_1_01');
      bloc.add(const ZipEvent.started());
      await ready(bloc);
      now = now.add(const Duration(seconds: 12));
      final done = await finish(bloc);
      final args = done.resultsExtra!;
      expect(args.title, 'Level 1 cleared');
      expect(args.local!.kind, LocalResultKind.level);
      expect(args.local!.label, 'Level 1 · Ink');
      expect(args.local!.againLocation, '/zip?mode=level&level=zip_1_01');
      expect(args.local!.level!.runStars, 3);
      expect(args.local!.level!.nextLevelId, 'zip_1_02');
      expect(args.local!.level!.opensNewWorld, isFalse);
      expect(progress.progress('zip')['zip_1_01']!.stars, 3);
      verifyNever(
        () => recordDailyClear(
          gameId: any(named: 'gameId'),
          dateId: any(named: 'dateId'),
        ),
      );
      verifyZeroInteractions(submitScore);
      await bloc.close();
    },
  );

  test('a hint adds no time and costs the no-hints star', () async {
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    bloc.add(const ZipEvent.hint());
    await bloc.stream.firstWhere((s) => s.hintsUsed == 1);
    now = now.add(const Duration(seconds: 10));
    final done = await finish(bloc);
    expect(done.timeSeconds, 10);
    expect(done.resultsExtra!.hintPenaltySeconds, 0);
    expect(done.resultsExtra!.local!.level!.runStars, 2);
    expect(done.resultsExtra!.local!.level!.usedHints, isTrue);
    await bloc.close();
  });

  test("a world's last level opens the next world", () async {
    final bloc = build('zip_1_02');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    final level = done.resultsExtra!.local!.level!;
    expect(level.nextLevelId, 'zip_2_01');
    expect(level.nextWorldTheme, 'metro');
    await bloc.close();
  });

  test('the last published level has no next level', () async {
    final bloc = build('zip_2_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    expect(done.resultsExtra!.local!.level!.nextLevelId, isNull);
    await bloc.close();
  });

  test('an unknown level fails and drops its draft', () async {
    drafts.runs['zip_level_zip_9_01'] = InProgressRun(
      gameId: 'zip',
      playId: 'level_zip_9_01',
      elapsedMs: 1000,
      board: const {'path': []},
    );
    final bloc = build('zip_9_01');
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.failed);
    expect(state.errorMessage, 'Could not load this level.');
    expect(drafts.runs, isEmpty);
    await bloc.close();
  });

  test('levels being unavailable keeps the draft', () async {
    drafts.runs['zip_level_zip_1_01'] = InProgressRun(
      gameId: 'zip',
      playId: 'level_zip_1_01',
      elapsedMs: 1000,
      board: const {'path': []},
    );
    final bloc = ZipBloc(
      mode: const PlayMode.level('zip_1_01'),
      levelWorlds: _OfflineWorlds(),
      recordLevelClear: RecordLevelClear(progress, analytics),
      inProgressRuns: drafts,
      submitScore: submitScore,
      submitLeaderboardTime: _MockSubmitLeaderboardTime(),
      recordDailyClear: recordDailyClear,
      getBestPoints: _MockGetBestPoints(),
      getBestTimeSeconds: _MockGetBestTimeSeconds(),
      isNewPersonalBest: _MockIsNewPersonalBest(),
      getClearBoard: _MockGetClearBoard(),
      analytics: analytics,
      hintQuota: UnlimitedHintQuotaRepositoryImpl(),
      clockNow: () => now,
      wait: (_) async {},
      fetchDailyLevel: (date, {period = const Duration(days: 1)}) =>
          throw StateError('a level run never reads a daily'),
    );
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    expect(state.status, ZipStatus.failed);
    expect(state.errorMessage, 'Could not load this level.');
    expect(bloc.levelSlot, isNull);
    expect(drafts.runs['zip_level_zip_1_01'], isNotNull);
    await bloc.close();
  });

  test('a run left halfway resumes from its draft', () async {
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    final state = await ready(bloc);
    bloc.add(ZipEvent.pathChanged(path: state.level.solution.sublist(0, 3)));
    await bloc.stream.firstWhere((s) => s.path.length == 3);
    expect(drafts.runs['zip_level_zip_1_01'], isNotNull);
    await bloc.close();

    final again = build('zip_1_01');
    again.add(const ZipEvent.started());
    final resumed = await ready(again);
    expect(resumed.path.length, 3);
    await again.close();
  });

  test('a replay with more stars improves the record', () async {
    await progress.record('zip', 'zip_1_01', stars: 2, seconds: 40);
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    final level = done.resultsExtra!.local!.level!;
    expect(level.previousStars, 2);
    expect(level.bestStars, 3);
    expect(level.moreStars, isTrue);
    expect(done.resultsExtra!.improved, isTrue);
    await bloc.close();
  });

  test('a worse replay keeps the record', () async {
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    bloc.add(const ZipEvent.hint());
    await bloc.stream.firstWhere((s) => s.hintsUsed == 1);
    now = now.add(const Duration(seconds: 20));
    final done = await finish(bloc);
    final level = done.resultsExtra!.local!.level!;
    expect(level.runStars, 2);
    expect(level.bestStars, 3);
    expect(done.resultsExtra!.improved, isFalse);
    await bloc.close();
  });

  test('a level with no time goal tops out at two stars', () async {
    final bloc = build(
      'zip_1_01',
      from: LevelCatalog([levelWorld(1, 1, targetSeconds: null)]),
    );
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    final done = await finish(bloc);
    final level = done.resultsExtra!.local!.level!;
    expect(level.runStars, 2);
    expect(level.targetSeconds, isNull);
    await bloc.close();
  });

  test('a clear logs level_cleared and the completed run', () async {
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    await finish(bloc);
    verify(
      () => analytics.logLevelCleared(
        gameId: 'zip',
        levelId: 'zip_1_01',
        world: 1,
        number: 1,
        stars: 3,
        firstClear: true,
        improved: false,
      ),
    ).called(1);
    verify(
      () => analytics.logGameCompleted(
        gameId: 'zip',
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        streak: any(named: 'streak'),
        dayId: 'level_zip_1_01',
        usedHints: false,
      ),
    ).called(1);
    await bloc.close();
  });

  test("a clear touches nothing of the day's puzzle", () async {
    final dailyKey = 'zip_${PlayPeriod.id(now, PlayPeriod.daily)}';
    final todayDraft = InProgressRun(
      gameId: 'zip',
      playId: PlayPeriod.id(now, PlayPeriod.daily),
      elapsedMs: 5000,
      board: const {'path': []},
    );
    drafts.runs[dailyKey] = todayDraft;
    final bloc = build('zip_1_01');
    bloc.add(const ZipEvent.started());
    await ready(bloc);
    now = now.add(const Duration(seconds: 12));
    await finish(bloc);
    expect(drafts.runs[dailyKey], same(todayDraft));
    expect(drafts.runs['zip_level_zip_1_01'], isNull);
    verifyZeroInteractions(submitLeaderboardTime);
    verifyZeroInteractions(getBestPoints);
    await bloc.close();
  });
}
