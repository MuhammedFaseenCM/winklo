import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/path_words/bloc/path_words_bloc.dart';
import 'package:winklo/features/path_words/bloc/path_words_event.dart';
import 'package:winklo/features/path_words/bloc/path_words_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGenerateDailyPathWords extends Mock
    implements GenerateDailyPathWords {}

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

class _FakeClock {
  _FakeClock(this._times);

  final List<DateTime> _times;
  var _i = 0;

  DateTime call() {
    final idx = _i < _times.length ? _i : _times.length - 1;
    _i++;
    return _times[idx];
  }
}

PathWordsPuzzle _tinyPuzzle({required DateTime day}) {
  return PathWordsPuzzle(
    id: 't',
    day: day,
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
}

PathWordsPuzzle _linePuzzle3({required DateTime day}) {
  // 3x3, single target along top row.
  return PathWordsPuzzle(
    id: 'line3',
    day: day,
    size: 3,
    letters: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
    targets: const [
      PathWordsTarget(
        id: 't0',
        word: 'abc',
        start: Cell(0, 0),
        path: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
        colorIndex: 0,
      ),
    ],
  );
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

void main() {
  late _MockGenerateDailyPathWords generateDaily;
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockAnalyticsRepository analytics;
  late _FakeHintQuota hintQuota;
  late List<Duration> waited;

  PathWordsBloc buildBloc({
    _FakeHintQuota? quota,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? wait,
    Duration celebrationDuration = const Duration(seconds: 2),
    _MemoryInProgressRuns? drafts,
    SfxService? sfx,
  }) {
    return PathWordsBloc(
      inProgressRuns: drafts ?? _MemoryInProgressRuns(),
      generateDailyPathWords: generateDaily,
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      analytics: analytics,
      hintQuota: quota ?? hintQuota,
      now: now ?? (() => DateTime(2026, 9, 17, 0, 0, 0)),
      wait: wait,
      celebrationDuration: celebrationDuration,
      sfx: sfx,
    );
  }

  setUp(() {
    generateDaily = _MockGenerateDailyPathWords();
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    analytics = _MockAnalyticsRepository();
    hintQuota = _FakeHintQuota(3);
    waited = <Duration>[];
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
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
    registerFallbackValue(DateTime(2026, 9, 17));
    registerFallbackValue(SfxId.tap);
  });

  blocTest<PathWordsBloc, PathWordsState>(
    'started loads daily puzzle and becomes ready',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) => b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17))),
    expect: () => [
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.loading)
          .having((s) => s.day, 'day', DateTime(2026, 9, 17)),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.ready)
          .having((s) => s.puzzle?.id, 'puzzle.id', 't')
          .having((s) => s.resumedAt, 'resumedAt', isNotNull)
          .having((s) => s.hintsRemaining, 'hintsRemaining', 3)
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having((s) => s.activePath, 'activePath', isEmpty),
    ],
    verify: (_) =>
        verify(() => generateDaily(day: DateTime(2026, 9, 17))).called(1),
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'started locks when today is already cleared',
    build: () {
      when(() => getBestPoints('path_words_20260917')).thenReturn(940);
      when(() => getBestTimeSeconds('path_words_20260917')).thenReturn(12);
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) => b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17))),
    expect: () => [
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.loading)
          .having((s) => s.day, 'day', DateTime(2026, 9, 17)),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.locked)
          .having((s) => s.finished, 'finished', isTrue)
          .having((s) => s.puzzle?.id, 'puzzle.id', 't')
          .having((s) => s.completedTargetIds, 'completedTargetIds', {
            't0',
            't1',
          }),
    ],
    verify: (_) {
      verify(() => generateDaily(day: DateTime(2026, 9, 17))).called(1);
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'completing all targets pauses on the board, then submits and navigates',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      when(
        () => submitScore(
          modeKey: 'path_words_20260917',
          points: 940,
          timeSeconds: 12,
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => recordDailyClear(gameId: GameIds.pathWords, dateId: '20260917'),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.pathWords,
          current: 3,
          longest: 5,
          lastClearedDateId: '20260917',
        ),
      );

      final clock = _FakeClock([
        DateTime(2026, 9, 17, 0, 0, 0), // bloc initial day
        DateTime(2026, 9, 17, 0, 0, 0), // resumedAt
        DateTime(2026, 9, 17, 0, 0, 12), // finish elapsed
      ]);

      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: clock.call,
        wait: (duration) async {
          waited.add(duration);
        },
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();

      // target t0: (0,0) -> (0,1)
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();

      // target t1: (1,0) -> (1,1)
      b.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.playing)
          .having((s) => s.activePath, 'activePath', [const Cell(0, 0)]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(0, 0),
            const Cell(0, 1),
          ])
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
      isA<PathWordsState>()
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            contains('t0'),
          )
          .having((s) => s.activePath, 'activePath', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.playing)
          .having((s) => s.activePath, 'activePath', [const Cell(1, 0)]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(1, 0),
            const Cell(1, 1),
          ])
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            contains('t0'),
          ),
      isA<PathWordsState>()
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            containsAll(['t0', 't1']),
          )
          .having((s) => s.activePath, 'activePath', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.celebrating)
          .having((s) => s.finished, 'finished', isTrue)
          .having((s) => s.points, 'points', 940)
          .having((s) => s.timeSeconds, 'timeSeconds', 12),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.submitting)
          .having((s) => s.finished, 'finished', isTrue)
          .having((s) => s.points, 'points', 940)
          .having((s) => s.timeSeconds, 'timeSeconds', 12),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.navigating)
          .having((s) => s.improved, 'improved', isTrue)
          .having((s) => s.resultsExtra?.title, 'title', 'Puzzle cleared!')
          .having((s) => s.resultsExtra?.points, 'points', 940)
          .having((s) => s.resultsExtra?.timeSeconds, 'timeSeconds', 12)
          .having((s) => s.resultsExtra?.replayDaily, 'replayDaily', isTrue)
          .having(
            (s) => s.resultsExtra?.replayRoute,
            'replayRoute',
            '/path-words',
          )
          .having((s) => s.resultsExtra?.currentStreak, 'currentStreak', 3)
          .having((s) => s.resultsExtra?.longestStreak, 'longestStreak', 5),
    ],
    verify: (_) {
      expect(waited, [const Duration(seconds: 2)]);
      verify(
        () => submitScore(
          modeKey: 'path_words_20260917',
          points: 940,
          timeSeconds: 12,
          usedHints: false,
          hadMistakes: false,
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.pathWords,
          timeSeconds: 12,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 3,
          dayId: '2026-09-17',
          playId: '20260917',
        ),
      ).called(1);
      verify(
        () => recordDailyClear(gameId: GameIds.pathWords, dateId: '20260917'),
      ).called(1);
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'dragging through a matching word does not complete until pointer up',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
        wait: (_) async {},
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 2)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 2)));
      await pumpEventQueue();
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(0, 0),
            const Cell(0, 1),
            const Cell(0, 2),
          ])
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(0, 0),
            const Cell(0, 1),
            const Cell(0, 2),
            const Cell(1, 2),
          ])
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having((s) => s.finished, 'finished', isFalse),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'completing a word happens on pointer up of an exact path',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerUp());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(0, 0),
            const Cell(0, 1),
          ])
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.completedTargetIds, 'completedTargetIds', {'t0'})
          .having((s) => s.activePath, 'activePath', isEmpty),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'undo shortens active path only',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();

      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      await pumpEventQueue();

      b.add(const PathWordsEvent.undo());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'dragging back onto the previous cell pops LIFO like Zip',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();

      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 2)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 0)));
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
        const Cell(0, 2),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'releasing on the last remaining cell clears the path',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();

      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerUp());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', isEmpty),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'drawing can start from any letter cell',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 1)));
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 1),
      ]),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'releasing an incomplete stroke keeps it and clears only the active path',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerUp());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having(
            (s) => s.placedPaths.map((stroke) => stroke.cells).toList(),
            'placedPaths',
            [
              [const Cell(0, 0), const Cell(0, 1)],
            ],
          ),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'pointer down on another letter starts a new stroke',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      // Not adjacent to the tip (0,1) — begin a fresh stroke here.
      b.add(const PathWordsEvent.pointerDown(Cell(2, 2)));
      b.add(const PathWordsEvent.pointerEnter(Cell(2, 1)));
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having(
            (s) => s.placedPaths.map((stroke) => stroke.cells).toList(),
            'placedPaths',
            [
              [const Cell(0, 0), const Cell(0, 1)],
            ],
          ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(2, 2),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(2, 2),
            const Cell(2, 1),
          ])
          .having(
            (s) => s.placedPaths.map((stroke) => stroke.cells).toList(),
            'placedPaths',
            [
              [const Cell(0, 0), const Cell(0, 1)],
            ],
          ),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'tapping a cell on an incorrect placed path truncates it',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 2)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(1, 1)));
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
        const Cell(1, 1),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
        const Cell(1, 1),
        const Cell(1, 2),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having((s) => s.placedPaths, 'placedPaths', hasLength(1)),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having((s) => s.placedPaths.single.cells, 'truncated', [
            const Cell(1, 0),
            const Cell(1, 1),
          ]),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'undo removes only the last placed path',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(2, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(2, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      b.add(const PathWordsEvent.undo());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
        const Cell(1, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having((s) => s.placedPaths, 'placedPaths', hasLength(1)),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(2, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(2, 0),
        const Cell(2, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having((s) => s.placedPaths, 'placedPaths', hasLength(2))
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.placedPaths, 'placedPaths', hasLength(1))
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having((s) => s.placedPaths.single.cells, 'remaining', [
            const Cell(1, 0),
            const Cell(1, 1),
          ]),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'undo of a found word unlocks that word',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      b.add(const PathWordsEvent.undo());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(0, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.completedTargetIds, 'completedTargetIds', {'t0'})
          .having((s) => s.placedPaths, 'placedPaths', hasLength(1)),
      isA<PathWordsState>()
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having((s) => s.placedPaths, 'placedPaths', isEmpty),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'hint clears incorrect placed paths before revealing',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
      ]),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(1, 0),
        const Cell(1, 1),
      ]),
      isA<PathWordsState>()
          .having((s) => s.placedPaths, 'placedPaths', hasLength(1))
          .having((s) => s.hintsRemaining, 'hintsRemaining', 3),
      isA<PathWordsState>()
          .having((s) => s.placedPaths, 'placedPaths', isEmpty)
          .having((s) => s.hintsRemaining, 'hintsRemaining', 2)
          .having((s) => s.hintRevealLength, 'hintRevealLength', 0),
      isA<PathWordsState>()
          .having((s) => s.hintsRemaining, 'hintsRemaining', 1)
          .having((s) => s.hintRevealLength, 'hintRevealLength', 1)
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 0)),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'hint decrements and sets hintFlashCell',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>()
          .having((s) => s.hintsRemaining, 'hintsRemaining', 2)
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 0))
          .having((s) => s.hintRevealLength, 'hintRevealLength', 1),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'later hints keep connected cells on the unsolved word',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>()
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 0))
          .having((s) => s.hintRevealLength, 'hintRevealLength', 1),
      isA<PathWordsState>()
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 1))
          .having((s) => s.hintRevealLength, 'hintRevealLength', 2),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'a third hint on a longer unsolved word adds the next connected cell',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _linePuzzle3(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having(
        (s) => s.hintRevealLength,
        'hintRevealLength',
        1,
      ),
      isA<PathWordsState>().having(
        (s) => s.hintRevealLength,
        'hintRevealLength',
        2,
      ),
      isA<PathWordsState>()
          .having((s) => s.hintRevealLength, 'hintRevealLength', 3)
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 2)),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'reset clears progress but preserves elapsed clock',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      final fixedNow = DateTime(2026, 9, 17, 0, 0, 0);
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => fixedNow,
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();

      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();

      b.add(const PathWordsEvent.reset());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.playing,
      ),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(0, 0),
            const Cell(0, 1),
          ])
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
      isA<PathWordsState>().having(
        (s) => s.completedTargetIds,
        'completedTargetIds',
        contains('t0'),
      ),
      isA<PathWordsState>()
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty)
          .having((s) => s.activePath, 'activePath', isEmpty)
          .having((s) => s.hintsRemaining, 'hintsRemaining', 3)
          .having(
            (s) => s.resumedAt,
            'resumedAt',
            DateTime(2026, 9, 17, 0, 0, 0),
          ),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'reset after two hint consumes leaves remaining at 1',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return buildBloc(quota: _FakeHintQuota(3));
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.hint());
      await pumpEventQueue();
      b.add(const PathWordsEvent.reset());
    },
    verify: (bloc) {
      expect(bloc.state.hintsRemaining, 1);
      expect(bloc.state.hintRevealLength, 0);
      expect(bloc.state.completedTargetIds, isEmpty);
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'reset after win is a no-op',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      when(
        () => submitScore(
          modeKey: 'path_words_20260917',
          points: 940,
          timeSeconds: 12,
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => recordDailyClear(gameId: GameIds.pathWords, dateId: '20260917'),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.pathWords,
          current: 3,
          longest: 5,
          lastClearedDateId: '20260917',
        ),
      );

      final clock = _FakeClock([
        DateTime(2026, 9, 17, 0, 0, 0), // bloc initial day
        DateTime(2026, 9, 17, 0, 0, 0), // resumedAt
        DateTime(2026, 9, 17, 0, 0, 12), // finish elapsed
      ]);

      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: clock.call,
        wait: (_) async {},
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();

      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();

      b.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();

      b.add(const PathWordsEvent.reset());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.playing)
          .having((s) => s.activePath, 'activePath', [const Cell(0, 0)]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(0, 0),
            const Cell(0, 1),
          ])
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
      isA<PathWordsState>()
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            contains('t0'),
          )
          .having((s) => s.activePath, 'activePath', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.playing)
          .having((s) => s.activePath, 'activePath', [const Cell(1, 0)]),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [
            const Cell(1, 0),
            const Cell(1, 1),
          ])
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            contains('t0'),
          ),
      isA<PathWordsState>()
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            containsAll(['t0', 't1']),
          )
          .having((s) => s.activePath, 'activePath', isEmpty),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.celebrating)
          .having((s) => s.finished, 'finished', isTrue),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.submitting)
          .having((s) => s.finished, 'finished', isTrue),
      isA<PathWordsState>()
          .having((s) => s.status, 'status', PathWordsStatus.navigating)
          .having((s) => s.finished, 'finished', isTrue)
          .having(
            (s) => s.completedTargetIds,
            'completedTargetIds',
            containsAll(['t0', 't1']),
          ),
    ],
    verify: (bloc) {
      expect(bloc.state.status, PathWordsStatus.navigating);
      expect(bloc.state.finished, isTrue);
    },
  );

  test(
    'resume after day rolls over starts next day and clears stale draft',
    () async {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      final drafts = _MemoryInProgressRuns();
      final day = DateTime(2026, 9, 17);
      var now = day;
      final bloc = buildBloc(now: () => now, drafts: drafts);
      bloc.add(PathWordsEvent.started(date: day));
      await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

      now = day.add(const Duration(seconds: 5));
      bloc.add(const PathWordsEvent.pauseRun());
      await bloc.stream.firstWhere((s) => s.resumedAt == null);
      expect(drafts.runs['${GameIds.pathWords}_20260917'], isNotNull);
      expect(bloc.state.day, DateTime(2026, 9, 17));

      now = DateTime(2026, 9, 18);
      bloc.add(const PathWordsEvent.resumeRun());
      await bloc.stream.firstWhere(
        (s) =>
            s.status == PathWordsStatus.ready && s.day == DateTime(2026, 9, 18),
      );

      expect(bloc.state.day, DateTime(2026, 9, 18));
      expect(bloc.state.elapsedMs, 0);
      expect(drafts.runs['${GameIds.pathWords}_20260917'], isNull);
      await bloc.close();
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'failed same-length word attempt sets an off-board rule tip',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return PathWordsBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        generateDailyPathWords: generateDaily,
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        hintQuota: hintQuota,
        now: () => DateTime(2026, 9, 17, 0, 0, 0),
      );
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerUp());
    },
    expect: () => [
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.loading,
      ),
      isA<PathWordsState>().having(
        (s) => s.status,
        'status',
        PathWordsStatus.ready,
      ),
      isA<PathWordsState>()
          .having((s) => s.activePath, 'activePath', [const Cell(0, 0)])
          .having((s) => s.ruleTip, 'ruleTip', isNull),
      isA<PathWordsState>().having((s) => s.activePath, 'activePath', [
        const Cell(0, 0),
        const Cell(1, 0),
      ]),
      isA<PathWordsState>()
          .having((s) => s.ruleTip, 'ruleTip', AppStrings.pathWordsTipMatchList)
          .having((s) => s.completedTargetIds, 'completedTargetIds', isEmpty),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'pointer enter that grows the path plays tap',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      final sfx = _MockSfx();
      when(() => sfx.play(any())).thenAnswer((_) async {});
      return buildBloc(sfx: sfx);
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      await pumpEventQueue();
    },
    verify: (b) {
      verify(() => b.sfx!.play(SfxId.tap)).called(1);
      verifyNever(() => b.sfx!.play(SfxId.success));
      verifyNever(() => b.sfx!.play(SfxId.reject));
      verifyNever(() => b.sfx!.play(SfxId.clear));
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'finding a word plays success',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      final sfx = _MockSfx();
      when(() => sfx.play(any())).thenAnswer((_) async {});
      return buildBloc(sfx: sfx);
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
    },
    verify: (b) {
      verify(() => b.sfx!.play(SfxId.tap)).called(1);
      verify(() => b.sfx!.play(SfxId.success)).called(1);
      verifyNever(() => b.sfx!.play(SfxId.reject));
      verifyNever(() => b.sfx!.play(SfxId.clear));
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'failed word attempt stays silent for reject',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      final sfx = _MockSfx();
      when(() => sfx.play(any())).thenAnswer((_) async {});
      return buildBloc(sfx: sfx);
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
    },
    verify: (b) {
      verify(() => b.sfx!.play(SfxId.tap)).called(1);
      verifyNever(() => b.sfx!.play(SfxId.reject));
      verifyNever(() => b.sfx!.play(SfxId.success));
      verifyNever(() => b.sfx!.play(SfxId.clear));
    },
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'clearing every target plays success then clear',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
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
        () => recordDailyClear(
          gameId: any(named: 'gameId'),
          dateId: any(named: 'dateId'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.pathWords,
          current: 1,
          longest: 1,
          lastClearedDateId: '20260917',
        ),
      );
      final sfx = _MockSfx();
      when(() => sfx.play(any())).thenAnswer((_) async {});
      return buildBloc(sfx: sfx, wait: (_) async {});
    },
    act: (b) async {
      b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
      b.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      b.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      b.add(const PathWordsEvent.pointerUp());
      await pumpEventQueue();
    },
    verify: (b) {
      verify(() => b.sfx!.play(SfxId.tap)).called(2);
      verify(() => b.sfx!.play(SfxId.success)).called(2);
      verify(() => b.sfx!.play(SfxId.clear)).called(1);
      verifyNever(() => b.sfx!.play(SfxId.reject));
    },
  );
}
