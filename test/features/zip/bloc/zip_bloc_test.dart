import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
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

void main() {
  late _MockSubmitScore submitScore;
  late _MockSubmitLeaderboardTime submitLeaderboardTime;
  late _MockRecordDailyClear recordDailyClear;
  late _MockGetBestPoints getBestPoints;
  late _MockGetBestTimeSeconds getBestTimeSeconds;
  late _MockGetClearBoard getClearBoard;
  late MockAnalyticsRepository analytics;

  setUp(() {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    getClearBoard = _MockGetClearBoard();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
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
      ),
    ).thenAnswer((_) async {});
  });

  ZipBloc buildBloc({
    DateTime? now,
    DateTime Function()? clockNow,
    Future<void> Function(Duration duration)? wait,
    _MemoryInProgressRuns? drafts,
    Future<ZipLevel> Function(DateTime date, {Duration period})?
    fetchDailyLevel,
  }) {
    return ZipBloc(
      inProgressRuns: drafts ?? _MemoryInProgressRuns(),
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
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
      bloc.add(const ZipEvent.hint(hintsRemaining: 2));
      await bloc.stream.firstWhere((s) => s.usedHintsThisRun);
      bloc.add(const ZipEvent.completed());
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);

      verify(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: true,
          hadMistakes: false,
          board: any(named: 'board'),
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.zip,
          timeSeconds: any(named: 'timeSeconds'),
          usedHints: true,
          hadMistakes: false,
          currentStreak: 1,
          dayId: '2026-09-13',
          playId: '20260913',
        ),
      ).called(1);
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

      now = DateTime.utc(2026, 9, 13, 0, 0, 12);
      bloc.add(const ZipEvent.completed());
      await bloc.stream.firstWhere((s) => s.status == ZipStatus.navigating);

      expect(bloc.state.points, 940);
      expect(bloc.state.timeSeconds, 12);
      expect(bloc.state.resultsExtra?.currentStreak, 3);
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
        ),
      ).called(1);
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
      verify(() => analytics.logGameStarted(gameId: GameIds.zip)).called(1);
    },
  );

  blocTest<ZipBloc, ZipState>(
    'ZipHint marks usedHintsThisRun and logs hint_used',
    build: buildBloc,
    act: (b) => b.add(const ZipEvent.hint(hintsRemaining: 2)),
    expect: () => [
      isA<ZipState>().having(
        (s) => s.usedHintsThisRun,
        'usedHintsThisRun',
        isTrue,
      ),
    ],
    verify: (_) {
      verify(
        () => analytics.logHintUsed(gameId: GameIds.zip, hintsRemaining: 2),
      ).called(1);
    },
  );

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
    bloc.add(const ZipEvent.hint(hintsRemaining: 2));
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
        getClearBoard: getClearBoard,
        analytics: analytics,
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
