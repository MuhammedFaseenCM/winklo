import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/zip/bloc/zip_bloc.dart';
import 'package:winklo/features/zip/bloc/zip_event.dart';
import 'package:winklo/features/zip/bloc/zip_state.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

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
  late MockAnalyticsRepository analytics;

  setUp(() {
    submitScore = _MockSubmitScore();
    submitLeaderboardTime = _MockSubmitLeaderboardTime();
    recordDailyClear = _MockRecordDailyClear();
    getBestPoints = _MockGetBestPoints();
    getBestTimeSeconds = _MockGetBestTimeSeconds();
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    when(() => getBestPoints(any())).thenReturn(0);
    when(() => getBestTimeSeconds(any())).thenReturn(null);
    when(
      () => submitLeaderboardTime(
        gameId: any(named: 'gameId'),
        timeSeconds: any(named: 'timeSeconds'),
        usedHints: any(named: 'usedHints'),
        hadMistakes: any(named: 'hadMistakes'),
        currentStreak: any(named: 'currentStreak'),
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
    'ZipCompleted submits score, records streak, and signals navigation',
    () async {
      when(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: 940,
          timeSeconds: 12,
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
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(
          gameId: GameIds.zip,
          timeSeconds: 12,
          usedHints: false,
          hadMistakes: false,
          currentStreak: 3,
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

  blocTest<ZipBloc, ZipState>(
    'ZipReset clears usedHintsThisRun',
    build: buildBloc,
    act: (b) {
      b.add(const ZipEvent.hint(hintsRemaining: 2));
      b.add(const ZipEvent.reset());
    },
    expect: () => [
      isA<ZipState>().having(
        (s) => s.usedHintsThisRun,
        'usedHintsThisRun',
        isTrue,
      ),
      isA<ZipState>().having(
        (s) => s.usedHintsThisRun,
        'usedHintsThisRun',
        isFalse,
      ),
    ],
  );

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
        ),
      );
      await bloc.close();
    },
  );

  test(
    'resume after day rolls over starts next day and clears stale draft',
    () async {
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
      now = DateTime(2026, 9, 13, 0, 0, 5);
      bloc.add(const ZipEvent.pauseRun());
      await bloc.stream.firstWhere((s) => s.resumedAt == null);
      expect(drafts.runs['${GameIds.zip}_20260913'], isNotNull);
      expect(bloc.state.day, DateTime(2026, 9, 13));

      now = DateTime(2026, 9, 14);
      bloc.add(const ZipEvent.resumeRun());
      await bloc.stream.firstWhere(
        (s) => s.status == ZipStatus.ready && s.day == DateTime(2026, 9, 14),
      );

      expect(bloc.state.day, DateTime(2026, 9, 14));
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
}
