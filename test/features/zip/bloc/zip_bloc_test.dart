import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/game_streak.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/zip/bloc/zip_bloc.dart';
import 'package:winklo/features/zip/bloc/zip_event.dart';
import 'package:winklo/features/zip/bloc/zip_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

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
      ),
    ).thenAnswer((_) async {});
  });

  ZipBloc buildBloc({
    DateTime? now,
    Future<void> Function(Duration duration)? wait,
  }) {
    return ZipBloc(
      submitScore: submitScore,
      submitLeaderboardTime: submitLeaderboardTime,
      recordDailyClear: recordDailyClear,
      getBestPoints: getBestPoints,
      getBestTimeSeconds: getBestTimeSeconds,
      analytics: analytics,
      now: now ?? DateTime.utc(2026, 9, 13),
      wait: wait,
    );
  }

  blocTest<ZipBloc, ZipState>(
    'ZipStarted loads daily level for date',
    build: buildBloc,
    act: (b) => b.add(ZipEvent.started(date: DateTime.utc(2026, 9, 14))),
    expect: () => [
      isA<ZipState>()
          .having((s) => s.level.id, 'level.id', 'daily_20260914')
          .having((s) => s.status, 'status', ZipStatus.ready),
    ],
  );

  blocTest<ZipBloc, ZipState>(
    'starts locked when today is already cleared',
    build: () {
      when(() => getBestPoints('zip_daily_20260913')).thenReturn(900);
      when(() => getBestTimeSeconds('zip_daily_20260913')).thenReturn(12);
      return buildBloc();
    },
    expect: () => <ZipState>[],
    verify: (b) {
      expect(b.state.status, ZipStatus.locked);
      expect(b.state.finished, isTrue);
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
          .having((s) => s.status, 'status', ZipStatus.locked)
          .having((s) => s.finished, 'finished', isTrue),
    ],
  );

  blocTest<ZipBloc, ZipState>(
    'ZipCompleted submits score, records streak, and signals navigation',
    build: () {
      when(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: 900,
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

      return buildBloc(wait: (_) async {});
    },
    act: (b) => b.add(const ZipEvent.completed(points: 900, timeSeconds: 12)),
    expect: () => [
      isA<ZipState>()
          .having((s) => s.status, 'status', ZipStatus.celebrating)
          .having((s) => s.finished, 'finished', isTrue)
          .having((s) => s.points, 'points', 900)
          .having((s) => s.timeSeconds, 'timeSeconds', 12),
      isA<ZipState>().having((s) => s.status, 'status', ZipStatus.submitting),
      isA<ZipState>()
          .having((s) => s.status, 'status', ZipStatus.navigating)
          .having((s) => s.improved, 'improved', isTrue)
          .having(
            (s) => s.resultsExtra?.title,
            'title',
            AppStrings.zipClearedTitle,
          )
          .having((s) => s.resultsExtra?.timeSeconds, 'timeSeconds', 12)
          .having((s) => s.resultsExtra?.replayDaily, 'replayDaily', isTrue)
          .having((s) => s.resultsExtra?.currentStreak, 'currentStreak', 3)
          .having((s) => s.resultsExtra?.longestStreak, 'longestStreak', 5),
    ],
    verify: (_) {
      verify(
        () => submitScore(
          modeKey: 'zip_daily_20260913',
          points: 900,
          timeSeconds: 12,
        ),
      ).called(1);
      verify(
        () => submitLeaderboardTime(gameId: GameIds.zip, timeSeconds: 12),
      ).called(1);
      verify(
        () => recordDailyClear(gameId: GameIds.zip, dateId: '20260913'),
      ).called(1);
      verify(
        () => analytics.logGameCompleted(
          gameId: GameIds.zip,
          points: 900,
          timeSeconds: 12,
          streak: 3,
        ),
      ).called(1);
    },
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
    'ZipHint logs hint_used',
    build: buildBloc,
    act: (b) => b.add(const ZipEvent.hint(hintsRemaining: 2)),
    expect: () => <ZipState>[],
    verify: (_) {
      verify(
        () => analytics.logHintUsed(gameId: GameIds.zip, hintsRemaining: 2),
      ).called(1);
    },
  );

  blocTest<ZipBloc, ZipState>(
    'minute play period uses a new lock key each minute',
    build: () {
      when(() => getBestPoints('zip_daily_202609201431')).thenReturn(900);
      return ZipBloc(
        submitScore: submitScore,
        submitLeaderboardTime: submitLeaderboardTime,
        recordDailyClear: recordDailyClear,
        getBestPoints: getBestPoints,
        getBestTimeSeconds: getBestTimeSeconds,
        analytics: analytics,
        now: DateTime(2026, 9, 20, 14, 31, 40),
        playPeriod: PlayPeriod.minute,
      );
    },
    expect: () => <ZipState>[],
    verify: (b) {
      expect(b.state.level.id, 'daily_202609201431');
      expect(b.state.status, ZipStatus.locked);
    },
  );

  blocTest<ZipBloc, ZipState>(
    'ZipCompleted is ignored when the daily puzzle is already locked',
    build: () {
      when(() => getBestPoints('zip_daily_20260913')).thenReturn(900);
      return buildBloc();
    },
    act: (b) => b.add(const ZipEvent.completed(points: 900, timeSeconds: 12)),
    expect: () => <ZipState>[],
    verify: (_) {
      verifyNever(
        () => submitScore(
          modeKey: any(named: 'modeKey'),
          points: any(named: 'points'),
          timeSeconds: any(named: 'timeSeconds'),
        ),
      );
    },
  );
}
