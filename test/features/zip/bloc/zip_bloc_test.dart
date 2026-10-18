import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/hint_quota_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/get_clear_board.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/zip/bloc/zip_bloc.dart';
import 'package:winklo/features/zip/bloc/zip_event.dart';
import 'package:winklo/features/zip/bloc/zip_state.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:winklo/features/zip/logic/zip_board_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _FakeHintQuota implements HintQuotaRepository {
  _FakeHintQuota([this._used = 0]);

  int _used;

  @override
  Future<int> consume(String gameId, String playId) async => ++_used;

  @override
  int usedFor(String gameId, String playId) => _used;

  @override
  Future<bool> restoreUsed(String gameId, String playId, int used) async =>
      false;
}

void main() {
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockIsNewPersonalBest isNewPersonalBest;
  late _MockGetClearBoard getClearBoard;
  late MockAnalyticsRepository analytics;

  setUp(() {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    isNewPersonalBest = _MockIsNewPersonalBest();
    getClearBoard = _MockGetClearBoard();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    when(
      () => isNewPersonalBest(
        gameId: any(named: 'gameId'),
        playId: any(named: 'playId'),
        timeSeconds: any(named: 'timeSeconds'),
      ),
    ).thenReturn(false);
    when(() => getClearBoard(any())).thenReturn(null);
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
  });

  ZipBloc buildBloc({
    DateTime? now,
    DateTime Function()? clockNow,
    Future<void> Function(Duration duration)? wait,
    _MemoryInProgressRuns? drafts,
    _FakeHintQuota? quota,
    Future<ZipLevel> Function(DateTime date, {Duration period})?
    fetchDailyLevel,
  }) {
    return ZipBloc(
      hintQuota: quota ?? _FakeHintQuota(),
      inProgressRuns: drafts ?? _MemoryInProgressRuns(),
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      isNewPersonalBest: isNewPersonalBest,
      getClearBoard: getClearBoard,
      analytics: analytics,
      now: now ?? DateTime.utc(2026, 9, 13),
      clockNow: clockNow,
      wait: wait,
      fetchDailyLevel:
          fetchDailyLevel ??
          ((date, {period = PlayPeriod.daily}) async =>
              DailyPuzzleGenerator.forDate(date, period: period)),
    );
  }

  test(
    'ZipCompleted after a hint passes usedHints to score and board',
    () async {
      when(
        () => submitScore(
          modeKey: any(named: 'modeKey'),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          board: any(named: 'board'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => recordDailyClear(
          gameId: any(named: 'gameId'),
          dateId: any(named: 'dateId'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.zip,
          current: 1,
          longest: 1,
          lastClearedDateId: '20260913',
        ),
      );

      final bloc = buildBloc(
        now: DateTime.utc(2026, 9, 13),
        clockNow: () => DateTime.utc(2026, 9, 13),
        wait: (_) async {},
      );
      bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
      bloc.add(const ZipEvent.hint());
      await bloc.stream.firstWhere((s) => s.usedHintsThisRun);
      bloc.add(const ZipEvent.completed());
      final done = await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.navigating,
      );

      // No time passed; the hint's 10s is the whole time.
      expect(done.timeSeconds, 10);
      expect(done.resultsExtra?.hintPenaltySeconds, 10);
      verify(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: any(named: 'points'),
          timeSeconds: 10,
          usedHints: true,
          hadMistakes: false,
          board: any(named: 'board'),
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.zip,
          timeSeconds: 10,
          usedHints: true,
          hadMistakes: false,
          currentStreak: 1,
          dayId: '2026-09-13',
          playId: '20260913',
          proof: any(named: 'proof'),
        ),
      ).called(1);
      verify(
        () => analytics.logGameCompleted(
          gameId: GameIds.zip,
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          streak: 1,
          dayId: '20260913',
          usedHints: true,
        ),
      ).called(1);
      // Review reads the clear back from the key it was saved under.
      expect(bloc.clearModeKey, 'zip_daily_20260913');
      await bloc.close();
    },
  );

  test(
    'ZipCompleted submits score, records streak, and signals navigation',
    () async {
      when(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: 940,
          timeSeconds: 12,
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          board: any(named: 'board'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => recordDailyClear(gameId: GameIds.zip, dateId: '20260913'),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.zip,
          current: 3,
          longest: 5,
          lastClearedDateId: '20260913',
        ),
      );

      var now = DateTime.utc(2026, 9, 13);
      final bloc = buildBloc(
        now: DateTime.utc(2026, 9, 13),
        clockNow: () => now,
        wait: (_) async {},
      );
      bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);

      bloc.add(ZipEvent.pathChanged(path: const [Cell(0, 0), Cell(0, 1)]));
      now = DateTime.utc(2026, 9, 13, 0, 0, 12);
      bloc.add(const ZipEvent.completed());
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);

      expect(bloc.state.points, 940);
      expect(bloc.state.timeSeconds, 12);
      expect(bloc.state.resultsExtra?.currentStreak, 3);
      expect(bloc.state.resultsExtra?.day, DateTime(2026, 9, 13));
      verify(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: 940,
          timeSeconds: 12,
          usedHints: false,
          hadMistakes: false,
          board: any(named: 'board'),
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.zip,
          timeSeconds: 12,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 3,
          dayId: '2026-09-13',
          playId: '20260913',
          proof: any(
            named: 'proof',
            that: isA<ZipLeaderboardProof>().having(
              (p) => p.path,
              'path',
              const [Cell(0, 0), Cell(0, 1)],
            ),
          ),
        ),
      ).called(1);
      // Results keeps the proof for a guest who signs in to save the time.
      expect(
        bloc.state.resultsExtra?.leaderboardProof,
        isA<ZipLeaderboardProof>(),
      );
      await bloc.close();
    },
  );

  blocTest<ZipBloc, ZipState>(
    'ZipStarted loads daily level for date',
    build: buildBloc,
    act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14))),
    expect: () => [
      isA<ZipState>()
          .having((s) => s.level.id, 'level.id', 'daily_20260914')
          .having((s) => s.status, 'status', ZipStatus.initial),
      isA<ZipState>()
          .having((s) => s.level.id, 'level.id', 'daily_20260914')
          .having((s) => s.status, 'status', ZipStatus.ready),
    ],
  );

  blocTest<ZipBloc, ZipState>(
    'starts initial when today is already cleared (await fetch)',
    build: () {
      when(() => getBestPoints('zip_daily_20260913')).thenReturn(900);
      when(() => getBestTimeSeconds('zip_daily_20260913')).thenReturn(12);
      return buildBloc();
    },
    expect: () => <ZipState>[],
    verify: (b) {
      expect(b.state.status, ZipStatus.initial);
      expect(b.state.finished, isFalse);
    },
  );

  blocTest<ZipBloc, ZipState>(
    'ZipStarted transitions from initial to ready',
    build: buildBloc,
    act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14))),
    verify: (b) {
      expect(b.state.status, ZipStatus.ready);
    },
  );

  blocTest<ZipBloc, ZipState>(
    'ZipStarted stays locked when that day is already cleared',
    build: () {
      when(() => getBestPoints('zip_daily_20260914')).thenReturn(800);
      return buildBloc();
    },
    act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14))),
    expect: () => [
      isA<ZipState>()
          .having((s) => s.level.id, 'level.id', 'daily_20260914')
          .having((s) => s.status, 'status', ZipStatus.initial),
      isA<ZipState>()
          .having((s) => s.level.id, 'level.id', 'daily_20260914')
          .having((s) => s.status, 'status', ZipStatus.locked)
          .having((s) => s.finished, 'finished', isTrue),
    ],
  );

  blocTest<ZipBloc, ZipState>(
    'ZipStarted fails when daily level fetch throws',
    build: () => buildBloc(
      fetchDailyLevel: (date, {period = PlayPeriod.daily}) async {
        throw StateError('backend down');
      },
    ),
    act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13))),
    expect: () => [
      isA<ZipState>().having((s) => s.status, 'status', ZipStatus.failed),
    ],
  );

  blocTest<ZipBloc, ZipState>(
    'ZipStarted logs game_started when unlocked',
    build: buildBloc,
    act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14))),
    verify: (_) {
      verify(
        () => analytics.logGameStarted(
          gameId: GameIds.zip,
          dayId: '20260914',
          resumed: false,
        ),
      ).called(1);
    },
  );

  test('returning to a saved run logs game_started as resumed', () async {
    final drafts = _MemoryInProgressRuns();
    drafts.runs['${GameIds.zip}_20260913'] = const InProgressRun(
      gameId: GameIds.zip,
      playId: '20260913',
      elapsedMs: 4000,
      board: {'path': <List<int>>[]},
    );
    final bloc = buildBloc(now: DateTime(2026, 9, 13), drafts: drafts);

    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
    await pumpEventQueue();

    verify(
      () => analytics.logGameStarted(
        gameId: GameIds.zip,
        dayId: '20260913',
        resumed: true,
      ),
    ).called(1);
    await bloc.close();
  });

  test('ZipHint spends a hint, charges its time and logs hint_used', () async {
    final quota = _FakeHintQuota();
    final bloc = buildBloc(
      now: DateTime(2026, 9, 13),
      clockNow: () => DateTime(2026, 9, 13),
      quota: quota,
    );
    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    final ready = await bloc.stream.firstWhere(
      (s) => s.status == ZipStatus.ready,
    );
    expect(ready.hintsUsed, 0);

    bloc.add(const ZipEvent.hint());
    final first = await bloc.stream.firstWhere((s) => s.hintsUsed == 1);
    expect(first.usedHintsThisRun, isTrue);
    expect(first.elapsedMs, 10000);
    expect(first.isClockRunning, isTrue);

    bloc.add(const ZipEvent.hint());
    final second = await bloc.stream.firstWhere((s) => s.hintsUsed == 2);
    expect(second.elapsedMs, 30000);
    expect(quota.usedFor(GameIds.zip, '20260913'), 2);
    await pumpEventQueue();

    verify(
      () => analytics.logHintUsed(
        gameId: GameIds.zip,
        hintsUsed: 1,
        penaltySeconds: 10,
      ),
    ).called(1);
    verify(
      () => analytics.logHintUsed(
        gameId: GameIds.zip,
        hintsUsed: 2,
        penaltySeconds: 20,
      ),
    ).called(1);
    await bloc.close();
  });

  test('ZipHint before the board is ready costs nothing', () async {
    final quota = _FakeHintQuota();
    final bloc = buildBloc(quota: quota);
    bloc.add(const ZipEvent.hint());
    await pumpEventQueue();
    expect(quota.usedFor(GameIds.zip, '20260913'), 0);
    expect(bloc.state.usedHintsThisRun, isFalse);
    await bloc.close();
  });

  test('a fresh run carries the time of hints already counted', () async {
    // Ops replaced the board, or the run began on another device.
    final bloc = buildBloc(
      now: DateTime(2026, 9, 13),
      quota: _FakeHintQuota(2),
    );
    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    final ready = await bloc.stream.firstWhere(
      (s) => s.status == ZipStatus.ready,
    );
    expect(ready.hintsUsed, 2);
    expect(ready.elapsedMs, 30000);
    await bloc.close();
  });

  group('Results report the hint time the clock carries', () {
    setUp(() {
      when(
        () => submitScore(
          modeKey: any(named: 'modeKey'),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          board: any(named: 'board'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => recordDailyClear(
          gameId: any(named: 'gameId'),
          dateId: any(named: 'dateId'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.zip,
          current: 1,
          longest: 1,
          lastClearedDateId: '20260913',
        ),
      );
    });

    Future<ZipState> finish(ZipBloc bloc) async {
      bloc.add(ZipEvent.pathChanged(path: bloc.state.level.solution));
      bloc.add(const ZipEvent.completed());
      return bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);
    }

    test('a resumed run keeps the hint time it saved', () async {
      final drafts = _MemoryInProgressRuns();
      final quota = _FakeHintQuota();
      final first = buildBloc(
        now: DateTime(2026, 9, 13),
        drafts: drafts,
        quota: quota,
      );
      first.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
      await first.stream.firstWhere((s) => s.status == ZipStatus.ready);
      first.add(const ZipEvent.hint());
      await first.stream.firstWhere((s) => s.hintsUsed == 1);
      await pumpEventQueue();
      await first.close();
      expect(drafts.runs['${GameIds.zip}_20260913']?.hintPenaltySeconds, 10);

      final again = buildBloc(
        now: DateTime(2026, 9, 13),
        drafts: drafts,
        quota: quota,
        wait: (_) async {},
      );
      again.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
      final resumed = await again.stream.firstWhere(
        (s) => s.status == ZipStatus.ready,
      );
      expect(resumed.hintPenaltySeconds, 10);
      final done = await finish(again);
      expect(done.timeSeconds, 10);
      expect(done.resultsExtra?.hintPenaltySeconds, 10);
      await again.close();
    });

    test('a run saved before hints cost time reports none', () async {
      // Saved by the previous build: two hints counted, none charged.
      final drafts = _MemoryInProgressRuns();
      final level = DailyPuzzleGenerator.forDate(DateTime(2026, 9, 13));
      drafts.runs['${GameIds.zip}_20260913'] = InProgressRun(
        gameId: GameIds.zip,
        playId: '20260913',
        elapsedMs: 5000,
        usedHintsThisRun: true,
        board: const {'path': []},
        boardFingerprint: level.fingerprint,
      );
      final bloc = buildBloc(
        now: DateTime(2026, 9, 13),
        drafts: drafts,
        quota: _FakeHintQuota(2),
        wait: (_) async {},
      );
      bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
      final ready = await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.ready,
      );
      expect(ready.elapsedMs, 5000);
      final done = await finish(bloc);
      expect(done.timeSeconds, 5);
      expect(done.resultsExtra?.hintPenaltySeconds, 0);
      await bloc.close();
    });

    test('a hint that lands after the finish is dropped', () async {
      final quota = _FakeHintQuota();
      final bloc = buildBloc(
        now: DateTime(2026, 9, 13),
        quota: quota,
        wait: (_) async {},
      );
      bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
      bloc.add(ZipEvent.pathChanged(path: bloc.state.level.solution));
      bloc.add(const ZipEvent.hint());
      bloc.add(const ZipEvent.completed());
      final done = await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.navigating,
      );
      await pumpEventQueue();

      expect(done.timeSeconds, 0);
      expect(done.resultsExtra?.hintPenaltySeconds, 0);
      expect(bloc.state.hintPenaltySeconds, 0);
      expect(bloc.state.elapsedMs, 0);
      await bloc.close();
    });
  });

  test('a replaced board drops the saved run but keeps its hint use', () async {
    final drafts = _MemoryInProgressRuns();
    drafts.runs['${GameIds.zip}_20260913'] = const InProgressRun(
      gameId: GameIds.zip,
      playId: '20260913',
      elapsedMs: 9000,
      usedHintsThisRun: true,
      board: {
        'path': [
          [0, 0],
        ],
      },
      boardFingerprint: 'replaced',
    );
    final bloc = buildBloc(now: DateTime(2026, 9, 13), drafts: drafts);

    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    final ready = await bloc.stream.firstWhere(
      (s) => s.status == ZipStatus.ready,
    );

    expect(ready.path, isEmpty);
    expect(ready.elapsedMs, 0);
    // Hints spent on the old board still count, as after a reset.
    expect(ready.usedHintsThisRun, isTrue);
    // The old run is gone; what's saved now is the new board's run.
    final saved = drafts.runs['${GameIds.zip}_20260913'];
    expect(saved?.boardFingerprint, ready.level.fingerprint);
    expect(saved?.elapsedMs, 0);
    expect(saved?.usedHintsThisRun, isTrue);
    await bloc.close();
  });

  test('saved runs carry the board fingerprint', () async {
    final drafts = _MemoryInProgressRuns();
    final bloc = buildBloc(now: DateTime(2026, 9, 13), drafts: drafts);
    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    final ready = await bloc.stream.firstWhere(
      (s) => s.status == ZipStatus.ready,
    );

    bloc.add(ZipEvent.pathChanged(path: [const Cell(0, 0)]));
    await bloc.stream.firstWhere((s) => s.path.isNotEmpty);
    await pumpEventQueue();

    expect(
      drafts.runs['${GameIds.zip}_20260913']?.boardFingerprint,
      ready.level.fingerprint,
    );
    await bloc.close();
  });

  test('ZipReset clears the path but keeps usedHintsThisRun', () async {
    final drafts = _MemoryInProgressRuns();
    final bloc = buildBloc(
      now: DateTime(2026, 9, 13),
      drafts: drafts,
      wait: (_) async {},
    );
    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
    bloc.add(ZipEvent.pathChanged(path: [const Cell(0, 0)]));
    bloc.add(const ZipEvent.hint());
    bloc.add(const ZipEvent.reset());
    await bloc.stream.firstWhere((s) => s.usedHintsThisRun && s.path.isEmpty);
    await Future<void>.delayed(Duration.zero);

    // Clear is the everyday reset in Zip; it must not earn "Hint-free" back.
    expect(bloc.state.usedHintsThisRun, isTrue);
    expect(drafts.runs['${GameIds.zip}_20260913']?.usedHintsThisRun, isTrue);
    await bloc.close();
  });

  blocTest<ZipBloc, ZipState>(
    'minute play period uses a new lock key each minute',
    build: () {
      when(() => getBestPoints('zip_daily_202609201431')).thenReturn(900);
      return ZipBloc(
        inProgressRuns: _MemoryInProgressRuns(),
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        isNewPersonalBest: isNewPersonalBest,
        getClearBoard: getClearBoard,
        analytics: analytics,
        hintQuota: _FakeHintQuota(),
        now: DateTime(2026, 9, 20, 14, 31, 40),
        playPeriod: PlayPeriod.minute,
        fetchDailyLevel: (date, {period = PlayPeriod.daily}) async =>
            DailyPuzzleGenerator.forDate(date, period: period),
      );
    },
    expect: () => <ZipState>[],
    verify: (b) {
      expect(b.state.level.id, 'daily_202609201431');
      expect(b.state.status, ZipStatus.initial);
    },
  );

  test(
    'ZipCompleted is ignored when the daily puzzle is already locked',
    () async {
      when(() => getBestPoints('zip_daily_20260913')).thenReturn(900);
      final bloc = buildBloc();
      bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.locked);
      bloc.add(const ZipEvent.completed());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ZipStatus.locked);
      verifyNever(
        () => submitScore(
          modeKey: any(named: 'modeKey'),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          board: any(named: 'board'),
        ),
      );
      await bloc.close();
    },
  );

  Future<(ZipBloc, _MemoryInProgressRuns, void Function(DateTime))>
  pausedRunOn13th() async {
    final drafts = _MemoryInProgressRuns();
    var now = DateTime(2026, 9, 13);
    final bloc = buildBloc(
      now: DateTime(2026, 9, 13),
      clockNow: () => now,
      drafts: drafts,
      wait: (_) async {},
    );
    bloc.add(ZipEvent.started(date: DateTime(2026, 9, 13)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
    bloc.add(ZipEvent.pathChanged(path: [const Cell(0, 0)]));
    await Future<void>.delayed(Duration.zero);
    now = DateTime(2026, 9, 13, 23, 59, 50);
    bloc.add(const ZipEvent.pauseRun());
    await bloc.stream.firstWhere((s) => s.resumedAt == null);
    expect(drafts.runs['${GameIds.zip}_20260913'], isNotNull);
    return (bloc, drafts, (DateTime at) => now = at);
  }

  test('resume after midnight keeps the run for its own day', () async {
    final (bloc, drafts, setNow) = await pausedRunOn13th();

    setNow(DateTime(2026, 9, 14, 0, 5));
    bloc.add(const ZipEvent.resumeRun());
    await bloc.stream.firstWhere((s) => s.resumedAt != null);

    expect(bloc.state.day, DateTime(2026, 9, 13));
    expect(bloc.state.path, [const Cell(0, 0)]);
    expect(bloc.playId, '20260913');
    expect(drafts.runs['${GameIds.zip}_20260913'], isNotNull);
    await bloc.close();
  });

  test(
    'resume two days later starts the current day and clears the stale draft',
    () async {
      final (bloc, drafts, setNow) = await pausedRunOn13th();

      setNow(DateTime(2026, 9, 15));
      bloc.add(const ZipEvent.resumeRun());
      await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.ready && s.day == DateTime(2026, 9, 15),
      );

      expect(bloc.state.elapsedMs, 0);
      expect(bloc.state.path, isEmpty);
      expect(drafts.runs['${GameIds.zip}_20260913'], isNull);
      await bloc.close();
    },
  );

  test('clears draft after finish', () async {
    final drafts = _MemoryInProgressRuns();
    var now = DateTime.utc(2026, 9, 13);
    final bloc = buildBloc(
      now: DateTime.utc(2026, 9, 13),
      clockNow: () => now,
      drafts: drafts,
      wait: (_) async {},
    );
    when(
      () => submitScore(
        modeKey: any(named: 'modeKey'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        board: any(named: 'board'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => recordDailyClear(
        gameId: any(named: 'gameId'),
        dateId: any(named: 'dateId'),
      ),
    ).thenAnswer(
      (_) async => const GameStreak(
        gameId: GameIds.zip,
        current: 1,
        longest: 1,
        freezeAvailable: true,
      ),
    );

    bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
    bloc.add(ZipEvent.pathChanged(path: [const Cell(0, 0)]));
    await Future<void>.delayed(Duration.zero);
    expect(drafts.runs.isNotEmpty, isTrue);

    now = DateTime.utc(2026, 9, 13, 0, 0, 5);
    bloc.add(const ZipEvent.completed());
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);
    expect(drafts.runs.isEmpty, isTrue);
    await bloc.close();
  });

  test(
    'completion is a new personal best only when it beats earlier days',
    () async {
      var now = DateTime.utc(2026, 9, 13);
      final bloc = buildBloc(
        now: DateTime.utc(2026, 9, 13),
        clockNow: () => now,
        wait: (_) async {},
      );
      when(
        () => submitScore(
          modeKey: any(named: 'modeKey'),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: any(named: 'usedHints'),
          hadMistakes: any(named: 'hadMistakes'),
          board: any(named: 'board'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => recordDailyClear(
          gameId: any(named: 'gameId'),
          dateId: any(named: 'dateId'),
        ),
      ).thenAnswer(
        (_) async => const GameStreak(
          gameId: GameIds.zip,
          current: 1,
          longest: 1,
          freezeAvailable: true,
        ),
      );
      when(
        () => isNewPersonalBest(
          gameId: GameIds.zip,
          playId: '20260913',
          timeSeconds: 5,
        ),
      ).thenReturn(true);

      bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
      now = DateTime.utc(2026, 9, 13, 0, 0, 5);
      bloc.add(const ZipEvent.completed());
      final done = await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.navigating,
      );

      expect(done.improved, isTrue);
      expect(done.resultsExtra?.improved, isTrue);
      await bloc.close();
    },
  );

  test('ZipStarted locked review carries the saved winning path', () async {
    const saved = [Cell(0, 0), Cell(0, 1), Cell(1, 1)];
    when(() => getBestPoints('zip_daily_20260914')).thenReturn(800);
    when(
      () => getClearBoard('zip_daily_20260914'),
    ).thenReturn(ZipBoardCodec.encode(saved));
    final bloc = buildBloc();

    bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.locked);

    expect(bloc.state.path, saved);
    await bloc.close();
  });

  test('ZipStarted locked review without a saved path has none', () async {
    when(() => getBestPoints('zip_daily_20260914')).thenReturn(800);
    final bloc = buildBloc();

    bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.locked);

    expect(bloc.state.path, isEmpty);
    await bloc.close();
  });

  test('ZipCompleted stores the drawn path as the clear board', () async {
    when(
      () => submitScore(
        modeKey: any(named: 'modeKey'),
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        board: any(named: 'board'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => recordDailyClear(
        gameId: any(named: 'gameId'),
        dateId: any(named: 'dateId'),
      ),
    ).thenAnswer(
      (_) async => const GameStreak(
        gameId: GameIds.zip,
        current: 1,
        longest: 1,
        lastClearedDateId: '20260913',
      ),
    );
    const drawn = [Cell(2, 2), Cell(2, 1), Cell(1, 1)];

    final bloc = buildBloc(
      clockNow: () => DateTime.utc(2026, 9, 13),
      wait: (_) async {},
    );
    bloc.add(ZipEvent.started(date: DateTime.utc(2026, 9, 13)));
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.ready);
    bloc.add(const ZipEvent.pathChanged(path: drawn));
    await bloc.stream.firstWhere((s) => s.path.length == drawn.length);
    bloc.add(const ZipEvent.completed());
    await bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);

    verify(
      () => submitScore(
        modeKey: 'zip_daily_20260913',
        points: any(named: 'points'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        board: '2,2;2,1;1,1',
      ),
    ).called(1);
    await bloc.close();
  });
}
