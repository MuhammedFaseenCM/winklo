import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/level_world.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/level_play_stats_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/record_level_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_level_clear.dart';
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

class _MockSubmitLevelClear extends Mock implements SubmitLevelClear {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockHintQuota extends Mock implements HintQuotaRepository {}

class _Plays {
  final List<(String, String, LevelPlayEvent)> events = [];

  Future<void> call({
    required String game,
    required String levelId,
    required LevelPlayEvent event,
  }) async => events.add((game, levelId, event));
}

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
  final List<String> touched = [];
  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async {
    touched.add('${gameId}_$playId');
    return runs['${gameId}_$playId'];
  }

  @override
  Future<void> save(InProgressRun run) async =>
      runs['${run.gameId}_${run.playId}'] = run;
  @override
  Future<void> clear({required String gameId, required String playId}) async =>
      runs.remove('${gameId}_$playId');
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

String _id(int world, int n) =>
    'path_words_${world}_${n.toString().padLeft(2, '0')}';

LevelWorld _world(int order, int count, {String title = 'Animals'}) =>
    LevelWorld.fromJson('path_words_$order', {
      'game': 'path_words',
      'order': order,
      'published': true,
      'theme': 'ink',
      'title': title,
      'levels': [
        for (var n = 1; n <= count; n++)
          {..._tinyPuzzle(_id(order, n)).toJson(), 'targetSeconds': 30},
      ],
    });

void main() {
  final catalog = LevelCatalog([_world(1, 2), _world(2, 1, title: 'Foods')]);
  late _MockGenerateDailyPathWords generateDaily;
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockIsNewPersonalBest isNewPersonalBest;
  late _MockHintQuota dailyHints;
  late _MockSubmitLevelClear submit;
  late MockAnalyticsRepository analytics;
  late LevelProgressRepositoryImpl progress;
  late SharedPreferences prefs;
  late _MemoryInProgressRuns drafts;
  late _Plays plays;
  late DateTime now;

  setUpAll(() {
    registerFallbackValue(const PathWordsLeaderboardProof([]));
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
    submit = _MockSubmitLevelClear();
    when(
      () => submit(
        game: any(named: 'game'),
        levelId: any(named: 'levelId'),
        stars: any(named: 'stars'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        proof: any(named: 'proof'),
        improved: any(named: 'improved'),
      ),
    ).thenAnswer((_) async {});
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    progress = LevelProgressRepositoryImpl(prefs, currentUid: () => 'u1');
    drafts = _MemoryInProgressRuns();
    plays = _Plays();
    now = DateTime(2026, 11, 23, 9);
  });

  PathWordsBloc build(
    String levelId, {
    LevelWorldRepository? worlds,
    bool gated = false,
  }) => PathWordsBloc(
    mode: PlayMode.level(levelId),
    levelWorlds: worlds ?? _Worlds(catalog),
    recordLevelClear: RecordLevelClear(progress, analytics),
    submitLevelClear: submit,
    levelProgress: gated ? progress : null,
    recordLevelPlay: plays.call,
    generateDailyPathWords: generateDaily,
    submitScore: submitScore,
    submitLeaderboardTime: submitLeaderboardTime,
    recordDailyClear: recordDailyClear,
    getBestPoints: getBestPoints,
    getBestTimeSeconds: getBestTimeSeconds,
    isNewPersonalBest: isNewPersonalBest,
    analytics: analytics,
    hintQuota: UnlimitedHintQuotaRepositoryImpl(),
    inProgressRuns: drafts,
    now: () => now,
    wait: (_) async {},
  );

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

  Future<PathWordsState> solve(PathWordsBloc bloc) async {
    final done = bloc.stream.firstWhere(
      (s) => s.status == PathWordsStatus.navigating,
    );
    await trace(bloc, const [Cell(0, 0), Cell(0, 1)]);
    await trace(bloc, const [Cell(1, 0), Cell(1, 1)]);
    return done;
  }

  group('loading', () {
    test('the board comes from the catalog and a start is counted', () async {
      final bloc = build('path_words_1_02');
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.status, PathWordsStatus.ready);
      expect(state.puzzle!.id, 'path_words_1_02');
      expect(state.puzzle!.fingerprint, _tinyPuzzle('x').fingerprint);
      expect(bloc.levelSlot!.number, 2);
      expect(plays.events, [
        ('path_words', 'path_words_1_02', LevelPlayEvent.start),
      ]);
      verifyNever(
        () => generateDaily(
          day: any(named: 'day'),
          period: any(named: 'period'),
        ),
      );
      await bloc.close();
    });

    test('a locked level fails with the locked message', () async {
      final bloc = build('path_words_1_02', gated: true);
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.status, PathWordsStatus.failed);
      expect(state.errorMessage, 'This level is still locked.');
      expect(plays.events, isEmpty);
      await bloc.close();
    });

    test('an unknown level fails and drops its draft', () async {
      drafts.runs['path_words_level_path_words_9_01'] = const InProgressRun(
        gameId: 'path_words',
        playId: 'level_path_words_9_01',
        elapsedMs: 1000,
        board: {},
      );
      final bloc = build('path_words_9_01');
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.status, PathWordsStatus.failed);
      expect(state.errorMessage, 'Could not load this level.');
      expect(drafts.runs, isEmpty);
      await bloc.close();
    });

    test('levels being unavailable keeps the draft', () async {
      drafts.runs['path_words_level_path_words_1_01'] = const InProgressRun(
        gameId: 'path_words',
        playId: 'level_path_words_1_01',
        elapsedMs: 1000,
        board: {},
      );
      final bloc = build('path_words_1_01', worlds: _OfflineWorlds());
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.status, PathWordsStatus.failed);
      expect(state.errorMessage, 'Could not load this level.');
      expect(drafts.runs['path_words_level_path_words_1_01'], isNotNull);
      await bloc.close();
    });

    test(
      'a resumed draft restores the found words and counts no start',
      () async {
        final first = build('path_words_1_01');
        first.add(const PathWordsEvent.started());
        await ready(first);
        await trace(first, const [Cell(0, 0), Cell(0, 1)]);
        expect(first.state.completedTargetIds, {'t0'});
        await first.close();
        plays.events.clear();

        final again = build('path_words_1_01');
        again.add(const PathWordsEvent.started());
        final resumed = await ready(again);
        expect(resumed.completedTargetIds, {'t0'});
        expect(plays.events, isEmpty);
        await again.close();
      },
    );

    test('a draft for a changed board is dropped and counts a start', () async {
      drafts.runs['path_words_level_path_words_1_01'] = const InProgressRun(
        gameId: 'path_words',
        playId: 'level_path_words_1_01',
        elapsedMs: 1000,
        board: {},
        boardFingerprint: 'old-board',
      );
      final bloc = build('path_words_1_01');
      bloc.add(const PathWordsEvent.started());
      final state = await ready(bloc);
      expect(state.completedTargetIds, isEmpty);
      expect(plays.events.map((e) => e.$3), [LevelPlayEvent.start]);
      await bloc.close();
    });
  });

  group('clearing', () {
    test('records and submits the clear and shows the level results', () async {
      final bloc = build('path_words_1_01');
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      now = now.add(const Duration(seconds: 12));
      final done = await solve(bloc);

      final args = done.resultsExtra!;
      expect(args.title, 'Level 1 cleared');
      expect(args.gameId, 'path_words');
      expect(args.local!.kind, LocalResultKind.level);
      expect(args.local!.label, 'Level 1 · Animals');
      expect(
        args.local!.againLocation,
        '/path-words?mode=level&level=path_words_1_01',
      );
      final level = args.local!.level!;
      expect(level.game, 'path_words');
      expect(level.runStars, 3);
      expect(level.nextLevelId, 'path_words_1_02');
      expect(level.nextWorldName, isNull);
      expect(progress.progress('path_words')['path_words_1_01']!.stars, 3);
      verify(
        () => analytics.logLevelCleared(
          gameId: 'path_words',
          levelId: 'path_words_1_01',
          world: any(named: 'world'),
          number: any(named: 'number'),
          stars: any(named: 'stars'),
          firstClear: any(named: 'firstClear'),
          improved: any(named: 'improved'),
        ),
      ).called(1);
      final proof =
          verify(
                () => submit(
                  game: 'path_words',
                  levelId: 'path_words_1_01',
                  stars: 3,
                  timeSeconds: 12,
                  usedHints: false,
                  proof: captureAny(named: 'proof'),
                  improved: any(named: 'improved'),
                ),
              ).captured.single
              as PathWordsLeaderboardProof;
      expect(proof.strokes.map((s) => s.targetId), ['t0', 't1']);
      expect(plays.events.map((e) => e.$3), [
        LevelPlayEvent.start,
        LevelPlayEvent.clear,
      ]);
      await bloc.close();
    });

    test("the clear summary names the world's category", () async {
      final bloc = build('path_words_2_01');
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      final done = await solve(bloc);
      final summary = done.resultsExtra!.pathWords!;
      expect(summary.theme, 'Foods');
      expect(summary.words, ['ab', 'cd']);
      await bloc.close();
    });

    test("a world's last level names the next world", () async {
      final bloc = build('path_words_1_02');
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      final done = await solve(bloc);
      final level = done.resultsExtra!.local!.level!;
      expect(level.nextLevelId, 'path_words_2_01');
      expect(level.nextWorldName, 'Foods');
      await bloc.close();
    });

    test('Results do not wait for the network', () async {
      when(
        () => submit(
          game: any(named: 'game'),
          levelId: any(named: 'levelId'),
          stars: any(named: 'stars'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          proof: any(named: 'proof'),
          improved: any(named: 'improved'),
        ),
      ).thenAnswer((_) => Completer<void>().future);
      final bloc = build('path_words_1_01');
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      final done = await solve(bloc).timeout(const Duration(seconds: 5));
      expect(done.status, PathWordsStatus.navigating);
      await bloc.close();
    });

    test('touches no daily state', () async {
      final bloc = build('path_words_1_01');
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      await solve(bloc);

      verifyNever(
        () => recordDailyClear(
          gameId: any(named: 'gameId'),
          dateId: any(named: 'dateId'),
        ),
      );
      verifyZeroInteractions(submitScore);
      verifyZeroInteractions(submitLeaderboardTime);
      verifyZeroInteractions(isNewPersonalBest);
      verifyZeroInteractions(getBestPoints);
      verifyZeroInteractions(getBestTimeSeconds);
      verifyZeroInteractions(dailyHints);
      for (final key in prefs.getKeys()) {
        expect(key.startsWith('best_time_path_words_'), isFalse, reason: key);
        expect(key.startsWith('best_pts_path_words_'), isFalse, reason: key);
      }
      await bloc.close();
    });
  });

  group('hints', () {
    test(
      'a hint is counted, costs no time and costs the no-hints star',
      () async {
        final bloc = build('path_words_1_01');
        bloc.add(const PathWordsEvent.started());
        await ready(bloc);
        bloc.add(const PathWordsEvent.hint());
        await bloc.stream.firstWhere((s) => s.usedHintsThisRun);
        now = now.add(const Duration(seconds: 10));
        final done = await solve(bloc);

        expect(done.resultsExtra!.hintPenaltySeconds, 0);
        final level = done.resultsExtra!.local!.level!;
        expect(level.usedHints, isTrue);
        expect(level.runStars, 2);
        expect(plays.events.map((e) => e.$3), [
          LevelPlayEvent.start,
          LevelPlayEvent.hint,
          LevelPlayEvent.clear,
        ]);
        verify(
          () => submit(
            game: 'path_words',
            levelId: 'path_words_1_01',
            stars: any(named: 'stars'),
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: true,
            proof: any(named: 'proof'),
            improved: any(named: 'improved'),
          ),
        ).called(1);
        verifyZeroInteractions(dailyHints);
        await bloc.close();
      },
    );

    test('Reset does not start a run', () async {
      final bloc = build('path_words_1_01');
      bloc.add(const PathWordsEvent.started());
      await ready(bloc);
      bloc.add(const PathWordsEvent.reset());
      await pumpEventQueue();
      expect(plays.events.map((e) => e.$3), [LevelPlayEvent.start]);
      await bloc.close();
    });
  });
}
