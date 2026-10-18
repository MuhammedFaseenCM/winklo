import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/core/haptics/haptics_service.dart';
import 'package:winklo/core/sfx/sfx_id.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/word_list_repository.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
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

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

class _MockSfx extends Mock implements SfxService {}

class _MockHaptics extends Mock implements HapticsService {}

class _FakeHintQuota implements HintQuotaRepository {
  _FakeHintQuota([this._used = 0]);

  int _used;

  /// Play periods the bloc read or spent hints for, in order.
  final playIds = <String>[];

  @override
  Future<int> consume(String gameId, String playId) async {
    playIds.add(playId);
    return ++_used;
  }

  @override
  int usedFor(String gameId, String playId) {
    playIds.add(playId);
    return _used;
  }

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}

class _FakeWordList implements WordListRepository {
  _FakeWordList(this.words, {this.fails = false});

  final Set<String> words;
  final bool fails;
  var loads = 0;

  @override
  Future<Set<String>> loadBonusWords() async {
    loads++;
    if (fails) throw StateError('no list');
    return words;
  }

  @override
  Future<List<String>> loadDailyNouns({required String dateId}) =>
      throw UnimplementedError();

  @override
  Future<List<String>> loadPracticeWords() => throw UnimplementedError();

  @override
  Future<List<String>> loadEnglishWords({int minLen = 4, int maxLen = 10}) =>
      throw UnimplementedError();
}

/// w o r      "word" runs w-o-r and down to d; no target uses those cells.
/// x s d      target t1 "xs"
/// g h i      target t0 "ghi"
PathWordsPuzzle _bonusPuzzle({required DateTime day}) {
  return PathWordsPuzzle(
    id: 'bonus',
    day: day,
    size: 3,
    letters: const ['w', 'o', 'r', 'x', 's', 'd', 'g', 'h', 'i'],
    targets: const [
      PathWordsTarget(
        id: 't0',
        word: 'ghi',
        start: Cell(2, 0),
        path: [Cell(2, 0), Cell(2, 1), Cell(2, 2)],
        colorIndex: 0,
      ),
      PathWordsTarget(
        id: 't1',
        word: 'xs',
        start: Cell(1, 0),
        path: [Cell(1, 0), Cell(1, 1)],
        colorIndex: 1,
      ),
    ],
  );
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
  late _MockIsNewPersonalBest isNewPersonalBest;
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
    HapticsService? haptics,
    WordListRepository? wordList,
  }) {
    return PathWordsBloc(
      wordList: wordList,
      inProgressRuns: drafts ?? _MemoryInProgressRuns(),
      generateDailyPathWords: generateDaily,
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      isNewPersonalBest: isNewPersonalBest,
      analytics: analytics,
      hintQuota: quota ?? hintQuota,
      now: now ?? (() => DateTime(2026, 9, 17, 0, 0, 0)),
      wait: wait,
      celebrationDuration: celebrationDuration,
      sfx: sfx,
      haptics: haptics,
    );
  }

  setUp(() {
    generateDaily = _MockGenerateDailyPathWords();
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    isNewPersonalBest = _MockIsNewPersonalBest();
    analytics = _MockAnalyticsRepository();
    hintQuota = _FakeHintQuota();
    waited = <Duration>[];
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    when(
      () => isNewPersonalBest(
        gameId: any(named: 'gameId'),
        playId: any(named: 'playId'),
        timeSeconds: any(named: 'timeSeconds'),
      ),
    ).thenReturn(false);
    when(
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
    ).thenAnswer((_) async {});
    when(
      () => analytics.logGameStarted(
        gameId: any(named: 'gameId'),
        dayId: any(named: 'dayId'),
        resumed: any(named: 'resumed'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logGameCompleted(
        gameId: any(named: 'gameId'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        streak: any(named: 'streak'),
        dayId: any(named: 'dayId'),
        usedHints: any(named: 'usedHints'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logHintUsed(
        gameId: any(named: 'gameId'),
        hintsUsed: any(named: 'hintsUsed'),
        penaltySeconds: any(named: 'penaltySeconds'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logGameReset(gameId: any(named: 'gameId')),
    ).thenAnswer((_) async {});
    registerFallbackValue(DateTime(2026, 9, 17));
    registerFallbackValue(SfxId.tap);
    registerFallbackValue(HapticKind.tick);
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
        isNewPersonalBest: isNewPersonalBest,
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
          .having((s) => s.hintsUsed, 'hintsUsed', 0)
          .having((s) => s.elapsedMs, 'elapsedMs', 0)
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
        isNewPersonalBest: isNewPersonalBest,
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
      // Faster than every earlier daily: a new personal best.
      when(
        () => isNewPersonalBest(
          gameId: GameIds.pathWords,
          playId: '20260917',
          timeSeconds: 12,
        ),
      ).thenReturn(true);
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
        isNewPersonalBest: isNewPersonalBest,
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
          .having((s) => s.resultsExtra?.longestStreak, 'longestStreak', 5)
          .having((s) => s.resultsExtra?.day, 'day', DateTime(2026, 9, 17)),
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
          proof: any(
            named: 'proof',
            that: isA<PathWordsLeaderboardProof>().having(
              (p) => p.strokes,
              'strokes',
              isNotEmpty,
            ),
          ),
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
    'undo never unlocks a found word',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return buildBloc();
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
      // Undo has nothing to take back: no new state.
    ],
    verify: (b) {
      expect(b.state.completedTargetIds, {'t0'});
      expect(b.state.placedPaths, hasLength(1));
    },
  );

  test(
    'undo removes the last wrong stroke and keeps a word found after it',
    () async {
      // a b c   <- "abc"
      // d e f   <- free letters
      // g h i   <- "ghi"
      final puzzle = PathWordsPuzzle(
        id: 'lock',
        day: DateTime(2026, 9, 17),
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
          PathWordsTarget(
            id: 't1',
            word: 'ghi',
            start: Cell(2, 0),
            path: [Cell(2, 0), Cell(2, 1), Cell(2, 2)],
            colorIndex: 1,
          ),
        ],
      );
      when(
        () => generateDaily(day: any(named: 'day')),
      ).thenAnswer((_) async => puzzle);
      final drafts = _MemoryInProgressRuns();
      final bloc = buildBloc(drafts: drafts);
      bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

      // A wrong stroke, then a found word.
      bloc.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      bloc.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      bloc.add(const PathWordsEvent.pointerUp());
      bloc.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
      bloc.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
      bloc.add(const PathWordsEvent.pointerEnter(Cell(0, 2)));
      bloc.add(const PathWordsEvent.pointerUp());
      await bloc.stream.firstWhere((s) => s.completedTargetIds.contains('t0'));
      expect(bloc.state.placedPaths, hasLength(2));

      bloc.add(const PathWordsEvent.undo());
      await bloc.stream.firstWhere((s) => s.placedPaths.length == 1);
      expect(bloc.state.placedPaths.single.targetId, 't0');
      expect(bloc.state.completedTargetIds, {'t0'});
      await pumpEventQueue();
      final saved = drafts.runs['${GameIds.pathWords}_20260917'];
      expect(saved?.board['completedTargetIds'], ['t0']);
      expect(saved?.board['placedPaths'], hasLength(1));

      // Nothing wrong is left, so a second undo changes nothing.
      bloc.add(const PathWordsEvent.undo());
      await pumpEventQueue();
      expect(bloc.state.completedTargetIds, {'t0'});
      expect(bloc.state.placedPaths, hasLength(1));

      // While a stroke is being drawn, undo shortens it and leaves the board.
      bloc.add(const PathWordsEvent.pointerDown(Cell(1, 0)));
      bloc.add(const PathWordsEvent.pointerEnter(Cell(1, 1)));
      await pumpEventQueue();
      bloc.add(const PathWordsEvent.undo());
      await pumpEventQueue();
      expect(bloc.state.activePath, [const Cell(1, 0)]);
      expect(bloc.state.placedPaths, hasLength(1));
      await bloc.close();
    },
  );

  test('reset still clears found words', () async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final bloc = buildBloc();
    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);
    bloc.add(const PathWordsEvent.pointerDown(Cell(0, 0)));
    bloc.add(const PathWordsEvent.pointerEnter(Cell(0, 1)));
    bloc.add(const PathWordsEvent.pointerUp());
    await bloc.stream.firstWhere((s) => s.completedTargetIds.contains('t0'));
    bloc.add(const PathWordsEvent.reset());
    await bloc.stream.firstWhere((s) => s.completedTargetIds.isEmpty);
    expect(bloc.state.placedPaths, isEmpty);
    await bloc.close();
  });

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
        isNewPersonalBest: isNewPersonalBest,
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
          .having((s) => s.hintsUsed, 'hintsUsed', 0),
      isA<PathWordsState>()
          .having((s) => s.placedPaths, 'placedPaths', isEmpty)
          .having((s) => s.hintsUsed, 'hintsUsed', 1)
          .having((s) => s.elapsedMs, 'elapsedMs', 10000)
          .having((s) => s.hintRevealLength, 'hintRevealLength', 0),
      isA<PathWordsState>()
          .having((s) => s.hintsUsed, 'hintsUsed', 2)
          .having((s) => s.elapsedMs, 'elapsedMs', 30000)
          .having((s) => s.hintRevealLength, 'hintRevealLength', 1)
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 0)),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'hint counts, charges +10s and sets hintFlashCell',
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
        isNewPersonalBest: isNewPersonalBest,
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
          .having((s) => s.hintsUsed, 'hintsUsed', 1)
          .having((s) => s.elapsedMs, 'elapsedMs', 10000)
          .having((s) => s.hintFlashCell, 'hintFlashCell', const Cell(0, 0))
          .having((s) => s.hintRevealLength, 'hintRevealLength', 1),
    ],
    verify: (_) => verify(
      () => analytics.logHintUsed(
        gameId: GameIds.pathWords,
        hintsUsed: 1,
        penaltySeconds: 10,
      ),
    ).called(1),
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
        isNewPersonalBest: isNewPersonalBest,
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
          .having((s) => s.hintsUsed, 'hintsUsed', 0)
          .having(
            (s) => s.resumedAt,
            'resumedAt',
            DateTime(2026, 9, 17, 0, 0, 0),
          ),
    ],
  );

  blocTest<PathWordsBloc, PathWordsState>(
    'reset after two hints keeps their count and time',
    build: () {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      return buildBloc(quota: _FakeHintQuota());
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
      expect(bloc.state.hintsUsed, 2);
      expect(bloc.state.elapsedMs, 30000);
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
        isNewPersonalBest: isNewPersonalBest,
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
    'a word traced along another route counts, saves and stays found',
    () async {
      // Hand-made 3x3: "cat" stored as c(0,1) a(0,0) t(1,0), "ox" elsewhere,
      // and a spare "a" and "t" on the right that belong to no word.
      final puzzle = PathWordsPuzzle(
        id: 'alt',
        day: DateTime(2026, 9, 17),
        size: 3,
        letters: const ['a', 'c', 'a', 't', '', 't', 'o', 'x', ''],
        targets: const [
          PathWordsTarget(
            id: 't0',
            word: 'cat',
            start: Cell(0, 1),
            path: [Cell(0, 1), Cell(0, 0), Cell(1, 0)],
            colorIndex: 0,
          ),
          PathWordsTarget(
            id: 't1',
            word: 'ox',
            start: Cell(2, 0),
            path: [Cell(2, 0), Cell(2, 1)],
            colorIndex: 1,
          ),
        ],
      );
      when(
        () => generateDaily(day: any(named: 'day')),
      ).thenAnswer((_) async => puzzle);
      final drafts = _MemoryInProgressRuns();
      final bloc = buildBloc(drafts: drafts);
      bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

      bloc.add(const PathWordsEvent.pointerDown(Cell(0, 1)));
      bloc.add(const PathWordsEvent.pointerEnter(Cell(0, 2)));
      bloc.add(const PathWordsEvent.pointerEnter(Cell(1, 2)));
      bloc.add(const PathWordsEvent.pointerUp());
      await bloc.stream.firstWhere((s) => s.completedTargetIds.contains('t0'));
      await pumpEventQueue();

      final saved = drafts.runs['${GameIds.pathWords}_20260917'];
      expect(saved?.board['completedTargetIds'], ['t0']);

      // Found words are locked: undo can't take it back.
      bloc.add(const PathWordsEvent.undo());
      await pumpEventQueue();
      expect(bloc.state.completedTargetIds, {'t0'});
      expect(bloc.state.placedPaths, hasLength(1));
      await bloc.close();
    },
  );

  test('returning to a saved run logs game_started as resumed', () async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final drafts = _MemoryInProgressRuns();
    drafts.runs['${GameIds.pathWords}_20260917'] = const InProgressRun(
      gameId: GameIds.pathWords,
      playId: '20260917',
      elapsedMs: 3000,
      board: {
        'activePath': <List<int>>[],
        'placedPaths': <Map<String, Object>>[],
        'completedTargetIds': <String>[],
        'hintRevealLength': 0,
      },
    );
    final bloc = buildBloc(drafts: drafts);

    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);
    await pumpEventQueue();

    verify(
      () => analytics.logGameStarted(
        gameId: GameIds.pathWords,
        dayId: '20260917',
        resumed: true,
      ),
    ).called(1);
    await bloc.close();
  });

  test('a replaced board drops the saved run but keeps its hint use', () async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final drafts = _MemoryInProgressRuns();
    drafts.runs['${GameIds.pathWords}_20260917'] = const InProgressRun(
      gameId: GameIds.pathWords,
      playId: '20260917',
      elapsedMs: 7000,
      usedHintsThisRun: true,
      board: {
        'activePath': <List<int>>[],
        'placedPaths': [
          {
            'cells': [
              [0, 0],
              [0, 1],
            ],
            'colorIndex': 0,
            'targetId': 't0',
          },
        ],
        'completedTargetIds': ['t0'],
        'hintRevealLength': 0,
      },
      boardFingerprint: 'replaced',
    );
    final bloc = buildBloc(drafts: drafts);

    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    final ready = await bloc.stream.firstWhere(
      (s) => s.status == PathWordsStatus.ready,
    );

    expect(ready.completedTargetIds, isEmpty);
    expect(ready.placedPaths, isEmpty);
    expect(ready.elapsedMs, 0);
    // Hints spent on the old board still count, as after a reset.
    expect(ready.usedHintsThisRun, isTrue);
    // The old run is gone; what's saved now is the new board's run.
    final saved = drafts.runs['${GameIds.pathWords}_20260917'];
    expect(
      saved?.boardFingerprint,
      _tinyPuzzle(day: DateTime(2026, 9, 17)).fingerprint,
    );
    expect(saved?.elapsedMs, 0);
    expect(saved?.usedHintsThisRun, isTrue);
    await bloc.close();
  });

  test('a fresh run carries the time of hints already counted', () async {
    // Ops replaced the board, or the run began on another device.
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final bloc = buildBloc(quota: _FakeHintQuota(1));

    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    final ready = await bloc.stream.firstWhere(
      (s) => s.status == PathWordsStatus.ready,
    );

    expect(ready.hintsUsed, 1);
    expect(ready.elapsedMs, 10000);
    expect(ready.hintPenaltySeconds, 10);
    await bloc.close();
  });

  test('two quick hint taps reveal two letters, charging each once', () async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final bloc = buildBloc();
    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

    bloc.add(const PathWordsEvent.hint());
    bloc.add(const PathWordsEvent.hint());
    final second = await bloc.stream.firstWhere((s) => s.hintsUsed == 2);

    expect(second.hintRevealLength, 2);
    expect(second.elapsedMs, 30000);
    expect(second.hintPenaltySeconds, 30);
    await bloc.close();
  });

  test('a hinted clear posts its time with the hint time added', () async {
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
        bonusWords: any(named: 'bonusWords'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => recordDailyClear(gameId: GameIds.pathWords, dateId: '20260917'),
    ).thenAnswer(
      (_) async => const GameStreak(
        gameId: GameIds.pathWords,
        current: 1,
        longest: 1,
        lastClearedDateId: '20260917',
      ),
    );
    final bloc = buildBloc(celebrationDuration: Duration.zero);
    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

    bloc.add(const PathWordsEvent.hint());
    await bloc.stream.firstWhere((s) => s.hintsUsed == 1);
    for (final (from, to) in [
      (const Cell(0, 0), const Cell(0, 1)),
      (const Cell(1, 0), const Cell(1, 1)),
    ]) {
      bloc.add(PathWordsEvent.pointerDown(from));
      bloc.add(PathWordsEvent.pointerEnter(to));
      bloc.add(const PathWordsEvent.pointerUp());
    }
    final done = await bloc.stream.firstWhere(
      (s) => s.status == PathWordsStatus.navigating,
    );

    expect(done.timeSeconds, 10);
    expect(done.resultsExtra?.hintPenaltySeconds, 10);
    verify(
      () => submitLeaderboardTime(
        gameId: GameIds.pathWords,
        timeSeconds: 10,
        usedHints: true,
        hadMistakes: false,
        currentStreak: 1,
        dayId: any(named: 'dayId'),
        playId: '20260917',
        proof: any(named: 'proof'),
      ),
    ).called(1);
    await bloc.close();
  });

  test('saved runs carry the board fingerprint', () async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final drafts = _MemoryInProgressRuns();
    final bloc = buildBloc(drafts: drafts);
    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

    bloc.add(const PathWordsEvent.pauseRun());
    await bloc.stream.firstWhere((s) => s.resumedAt == null);
    await pumpEventQueue();

    expect(
      drafts.runs['${GameIds.pathWords}_20260917']?.boardFingerprint,
      _tinyPuzzle(day: DateTime(2026, 9, 17)).fingerprint,
    );
    await bloc.close();
  });

  Future<(PathWordsBloc, _MemoryInProgressRuns, void Function(DateTime))>
  pausedRunOn17th() async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final drafts = _MemoryInProgressRuns();
    final day = DateTime(2026, 9, 17);
    var now = day;
    final bloc = buildBloc(now: () => now, drafts: drafts);
    bloc.add(PathWordsEvent.started(date: day));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

    now = DateTime(2026, 9, 17, 23, 59, 50);
    bloc.add(const PathWordsEvent.pauseRun());
    await bloc.stream.firstWhere((s) => s.resumedAt == null);
    expect(drafts.runs['${GameIds.pathWords}_20260917'], isNotNull);
    return (bloc, drafts, (DateTime at) => now = at);
  }

  test('resume after midnight keeps the run for its own day', () async {
    final (bloc, drafts, setNow) = await pausedRunOn17th();

    setNow(DateTime(2026, 9, 18, 0, 5));
    bloc.add(const PathWordsEvent.resumeRun());
    await bloc.stream.firstWhere((s) => s.resumedAt != null);

    expect(bloc.state.day, DateTime(2026, 9, 17));
    expect(drafts.runs['${GameIds.pathWords}_20260917'], isNotNull);
    await bloc.close();
  });

  test('a hint after midnight spends the run\'s own day quota', () async {
    final (bloc, _, setNow) = await pausedRunOn17th();
    setNow(DateTime(2026, 9, 18, 0, 5));
    bloc.add(const PathWordsEvent.resumeRun());
    await bloc.stream.firstWhere((s) => s.resumedAt != null);
    hintQuota.playIds.clear();

    bloc.add(const PathWordsEvent.hint());
    await bloc.stream.firstWhere((s) => s.usedHintsThisRun);

    expect(hintQuota.playIds, everyElement('20260917'));
    expect(hintQuota.playIds, isNotEmpty);
    await bloc.close();
  });

  test(
    'resume two days later starts the current day and clears the stale draft',
    () async {
      final (bloc, drafts, setNow) = await pausedRunOn17th();

      setNow(DateTime(2026, 9, 19));
      bloc.add(const PathWordsEvent.resumeRun());
      await bloc.stream.firstWhere(
        (s) =>
            s.status == PathWordsStatus.ready && s.day == DateTime(2026, 9, 19),
      );

      expect(bloc.state.elapsedMs, 0);
      expect(drafts.runs['${GameIds.pathWords}_20260917'], isNull);
      await bloc.close();
    },
  );

  test('reset clears the board but keeps usedHintsThisRun', () async {
    when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
      (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
    );
    final drafts = _MemoryInProgressRuns();
    final bloc = buildBloc(drafts: drafts);
    bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
    await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);

    bloc.add(const PathWordsEvent.hint());
    await bloc.stream.firstWhere((s) => s.usedHintsThisRun);
    bloc.add(const PathWordsEvent.reset());
    await bloc.stream.firstWhere((s) => s.hintRevealLength == 0);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.usedHintsThisRun, isTrue);
    expect(
      drafts.runs['${GameIds.pathWords}_20260917']?.usedHintsThisRun,
      isTrue,
    );
    await bloc.close();
  });

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
        isNewPersonalBest: isNewPersonalBest,
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

  group('haptics', () {
    _MockHaptics stubHaptics() {
      final haptics = _MockHaptics();
      when(() => haptics.play(any())).thenReturn(null);
      return haptics;
    }

    blocTest<PathWordsBloc, PathWordsState>(
      'ticks per traced cell and a stronger one for a found word',
      build: () {
        when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
          (inv) async => _tinyPuzzle(day: inv.namedArguments[#day] as DateTime),
        );
        return buildBloc(haptics: stubHaptics());
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
        // The stroke's first cell ticks too, as in Zip.
        verify(() => b.haptics!.play(HapticKind.tick)).called(2);
        verify(() => b.haptics!.play(HapticKind.success)).called(1);
        verifyNever(() => b.haptics!.play(HapticKind.win));
      },
    );

    blocTest<PathWordsBloc, PathWordsState>(
      'the last word is a win, not another found word',
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
          (_) async => const GameStreak(gameId: GameIds.pathWords, current: 1),
        );
        return buildBloc(
          haptics: stubHaptics(),
          celebrationDuration: Duration.zero,
          wait: (_) async {},
        );
      },
      act: (b) async {
        b.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
        await pumpEventQueue();
        for (final word in const [
          [Cell(0, 0), Cell(0, 1)],
          [Cell(1, 0), Cell(1, 1)],
        ]) {
          b.add(PathWordsEvent.pointerDown(word.first));
          b.add(PathWordsEvent.pointerEnter(word.last));
          b.add(const PathWordsEvent.pointerUp());
          await pumpEventQueue();
        }
      },
      verify: (b) {
        verify(() => b.haptics!.play(HapticKind.success)).called(1);
        verify(() => b.haptics!.play(HapticKind.win)).called(1);
      },
    );
  });

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

  group('bonus words', () {
    const word = [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 2)];

    void trace(PathWordsBloc bloc, List<Cell> cells) {
      bloc.add(PathWordsEvent.pointerDown(cells.first));
      for (final cell in cells.skip(1)) {
        bloc.add(PathWordsEvent.pointerEnter(cell));
      }
      bloc.add(const PathWordsEvent.pointerUp());
    }

    Future<PathWordsBloc> ready({
      WordListRepository? wordList,
      _MemoryInProgressRuns? drafts,
      HapticsService? haptics,
    }) async {
      when(() => generateDaily(day: any(named: 'day'))).thenAnswer(
        (inv) async => _bonusPuzzle(day: inv.namedArguments[#day] as DateTime),
      );
      final bloc = buildBloc(
        wordList: wordList,
        drafts: drafts,
        haptics: haptics,
        wait: (_) async {},
      );
      bloc.add(PathWordsEvent.started(date: DateTime(2026, 9, 17)));
      await bloc.stream.firstWhere((s) => s.status == PathWordsStatus.ready);
      await pumpEventQueue();
      return bloc;
    }

    test(
      'a real word that is not a target is a bonus, not a wrong stroke',
      () async {
        final haptics = _MockHaptics();
        final drafts = _MemoryInProgressRuns();
        final words = _FakeWordList({'word', 'words'});
        final bloc = await ready(
          wordList: words,
          drafts: drafts,
          haptics: haptics,
        );

        trace(bloc, word);
        await bloc.stream.firstWhere((s) => s.bonusWords.isNotEmpty);
        expect(bloc.state.bonusWords, ['word']);
        expect(bloc.state.placedPaths, isEmpty);
        expect(bloc.state.activePath, isEmpty);
        expect(bloc.state.ruleTip, isNull);
        verify(() => haptics.play(HapticKind.light)).called(1);
        await pumpEventQueue();
        expect(
          drafts.runs['${GameIds.pathWords}_20260917']?.board['bonusWords'],
          ['word'],
        );
        expect(words.loads, 1);
        await bloc.close();
      },
    );

    test('the same word twice is a wrong stroke the second time', () async {
      final bloc = await ready(wordList: _FakeWordList({'word'}));
      trace(bloc, word);
      await bloc.stream.firstWhere((s) => s.bonusWords.isNotEmpty);
      trace(bloc, word);
      await bloc.stream.firstWhere((s) => s.placedPaths.isNotEmpty);
      expect(bloc.state.bonusWords, ['word']);
      expect(bloc.state.placedPaths.single.isCorrect, isFalse);
      await bloc.close();
    });

    test(
      'a stroke that spells no word, or a short one, is a wrong stroke',
      () async {
        final bloc = await ready(
          wordList: _FakeWordList({'word', 'xsdr', 'sdr'}),
        );
        // "dro" is not in the list.
        trace(bloc, const [Cell(1, 2), Cell(0, 2), Cell(0, 1)]);
        await bloc.stream.firstWhere((s) => s.placedPaths.length == 1);
        expect(bloc.state.bonusWords, isEmpty);
        await bloc.close();
      },
    );

    test('without the word list loaded, strokes work as before', () async {
      for (final wordList in [
        null,
        _FakeWordList({'word'}, fails: true),
      ]) {
        final bloc = await ready(wordList: wordList);
        trace(bloc, word);
        await bloc.stream.firstWhere((s) => s.placedPaths.isNotEmpty);
        expect(bloc.state.bonusWords, isEmpty);
        await bloc.close();
      }
    });

    test('bonus words come back with a saved run', () async {
      final drafts = _MemoryInProgressRuns();
      drafts.runs['${GameIds.pathWords}_20260917'] = const InProgressRun(
        gameId: GameIds.pathWords,
        playId: '20260917',
        elapsedMs: 3000,
        board: {
          'activePath': <List<int>>[],
          'placedPaths': <Map<String, Object>>[],
          'completedTargetIds': <String>[],
          'hintRevealLength': 0,
          'bonusWords': ['word', 7],
        },
      );
      final bloc = await ready(
        wordList: _FakeWordList({'word'}),
        drafts: drafts,
      );
      expect(bloc.state.bonusWords, ['word']);
      // Already found, so it is a wrong stroke now.
      trace(bloc, word);
      await bloc.stream.firstWhere((s) => s.placedPaths.isNotEmpty);
      expect(bloc.state.bonusWords, ['word']);
      await bloc.close();
    });

    test('undo leaves bonus words, reset clears them', () async {
      final bloc = await ready(wordList: _FakeWordList({'word'}));
      trace(bloc, word);
      await bloc.stream.firstWhere((s) => s.bonusWords.isNotEmpty);
      bloc.add(const PathWordsEvent.undo());
      await pumpEventQueue();
      expect(bloc.state.bonusWords, ['word']);
      bloc.add(const PathWordsEvent.reset());
      await bloc.stream.firstWhere((s) => s.bonusWords.isEmpty);
      await bloc.close();
    });

    test(
      'the clear saves them with the clear meta and leaves the flags, time and leaderboard alone',
      () async {
        when(
          () => submitScore(
            modeKey: any(named: 'modeKey'),
            points: any(named: 'points'),
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: any(named: 'usedHints'),
            hadMistakes: any(named: 'hadMistakes'),
            bonusWords: any(named: 'bonusWords'),
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
        final bloc = await ready(wordList: _FakeWordList({'word'}));
        trace(bloc, word);
        await bloc.stream.firstWhere((s) => s.bonusWords.isNotEmpty);
        trace(bloc, const [Cell(1, 0), Cell(1, 1)]);
        trace(bloc, const [Cell(2, 0), Cell(2, 1), Cell(2, 2)]);
        await bloc.stream.firstWhere(
          (s) => s.status == PathWordsStatus.navigating,
        );

        verify(
          () => submitScore(
            modeKey: 'path_words_20260917',
            points: any(named: 'points'),
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: false,
            hadMistakes: false,
            bonusWords: any(named: 'bonusWords', that: equals(['word'])),
          ),
        ).called(1);
        verify(
          () => submitLeaderboardTime(
            gameId: GameIds.pathWords,
            timeSeconds: any(named: 'timeSeconds'),
            usedHints: false,
            hadMistakes: false,
            currentStreak: 1,
            dayId: any(named: 'dayId'),
            playId: '20260917',
            proof: any(named: 'proof'),
          ),
        ).called(1);
        final summary = bloc.state.resultsExtra?.pathWords;
        expect(summary?.bonusWords, ['word']);
        expect(summary?.words, ['xs', 'ghi']);
        await bloc.close();
      },
    );

    test('a clear without bonus words sends none', () async {
      when(
        () => submitScore(
          modeKey: any(named: 'modeKey'),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          bonusWords: any(named: 'bonusWords'),
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
      final bloc = await ready(wordList: _FakeWordList({'word'}));
      trace(bloc, const [Cell(1, 0), Cell(1, 1)]);
      trace(bloc, const [Cell(2, 0), Cell(2, 1), Cell(2, 2)]);
      await bloc.stream.firstWhere(
        (s) => s.status == PathWordsStatus.navigating,
      );
      verify(
        () => submitScore(
          modeKey: 'path_words_20260917',
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: false,
          hadMistakes: false,
          bonusWords: null,
        ),
      ).called(1);
      expect(bloc.state.resultsExtra?.pathWords?.bonusWords, isEmpty);
      await bloc.close();
    });
  });
}
