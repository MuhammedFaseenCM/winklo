import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/zip_level.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/zip_level_repository.dart';
import '../../../domain/streak_calculator.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../../results/results_args.dart';
import '../logic/daily_puzzle_generator.dart';
import 'zip_event.dart';
import 'zip_state.dart';

class ZipBloc extends Bloc<ZipEvent, ZipState> {
  ZipBloc({
    required this.submitScore,
    required this.submitLeaderboardTime,
    required this.recordDailyClear,
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.analytics,
    ZipLevelRepository? zipLevelRepository,
    Future<ZipLevel> Function(DateTime date, {Duration period})? fetchDailyLevel,
    this.ignoreDailyLock = false,
    this.playPeriod = PlayPeriod.daily,
    this.celebrationDuration = const Duration(seconds: 2),
    DateTime? now,
    Future<void> Function(Duration duration)? wait,
  }) : fetchDailyLevel = fetchDailyLevel ??
           ((date, {period = PlayPeriod.daily}) =>
               (zipLevelRepository?.fetchDailyLevel(date, period: period) ??
                Future.value(DailyPuzzleGenerator.forDate(date, period: period)))),
       _wait = wait ?? ((duration) => Future<void>.delayed(duration)),
       super(
         _initialState(
           now ?? DateTime.now(),
           getBestPoints,
           getBestTimeSeconds,
           ignoreDailyLock: ignoreDailyLock,
           playPeriod: playPeriod,
         ),
       ) {
    on<ZipStarted>(_onStarted);
    on<ZipCompleted>(_onCompleted);
    on<ZipHint>(_onHint);
    on<ZipReset>(_onReset);
  }

  final SubmitScore submitScore;
  final SubmitLeaderboardTime submitLeaderboardTime;
  final RecordDailyClear recordDailyClear;
  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final AnalyticsRepository analytics;
  final Future<ZipLevel> Function(DateTime date, {Duration period}) fetchDailyLevel;
  final bool ignoreDailyLock;
  final Duration playPeriod;
  final Duration celebrationDuration;
  final Future<void> Function(Duration duration) _wait;

  static ZipState _initialState(
    DateTime now,
    GetBestPoints getBestPoints,
    GetBestTimeSeconds getBestTimeSeconds, {
    required bool ignoreDailyLock,
    required Duration playPeriod,
  }) {
    final state = ZipState.initial(now, period: playPeriod);
    if (ignoreDailyLock ||
        !_isCleared(
          modeKey: 'zip_${state.level.id}',
          getBestPoints: getBestPoints,
          getBestTimeSeconds: getBestTimeSeconds,
        )) {
      return state;
    }
    return state.copyWith(status: ZipStatus.locked, finished: true);
  }

  static bool _isCleared({
    required String modeKey,
    required GetBestPoints getBestPoints,
    required GetBestTimeSeconds getBestTimeSeconds,
  }) {
    return getBestPoints(modeKey) > 0 || getBestTimeSeconds(modeKey) != null;
  }

  Future<void> _onStarted(ZipStarted event, Emitter<ZipState> emit) async {
    final seed = event.date ?? DateTime.now();
    final day = DateTime(seed.year, seed.month, seed.day);
    final level = await fetchDailyLevel(seed, period: playPeriod);
    if (emit.isDone) return;
    final cleared =
        !ignoreDailyLock &&
        _isCleared(
          modeKey: 'zip_${level.id}',
          getBestPoints: getBestPoints,
          getBestTimeSeconds: getBestTimeSeconds,
        );
    emit(
      ZipState(
        day: day,
        level: level,
        status: cleared ? ZipStatus.locked : ZipStatus.ready,
        finished: cleared,
      ),
    );
    if (!cleared) {
      await analytics.logGameStarted(gameId: GameIds.zip);
    }
  }

  Future<void> _onCompleted(ZipCompleted event, Emitter<ZipState> emit) async {
    if (state.finished ||
        state.status == ZipStatus.celebrating ||
        state.status == ZipStatus.submitting ||
        state.status == ZipStatus.navigating) {
      return;
    }

    emit(
      state.copyWith(
        finished: true,
        status: ZipStatus.celebrating,
        points: event.points,
        timeSeconds: event.timeSeconds,
      ),
    );

    await _wait(celebrationDuration);
    if (emit.isDone) return;

    emit(state.copyWith(status: ZipStatus.submitting));

    final improved = await submitScore(
      modeKey: 'zip_${state.level.id}',
      points: event.points,
      timeSeconds: event.timeSeconds,
    );

    if (improved) {
      try {
        await submitLeaderboardTime(
          gameId: GameIds.zip,
          timeSeconds: event.timeSeconds,
        );
      } catch (_) {
        // Best-effort remote sync; local score already saved.
      }
    }

    final streak = await recordDailyClear(
      gameId: GameIds.zip,
      dateId: StreakCalculator.dateId(state.day),
    );

    await analytics.logGameCompleted(
      gameId: GameIds.zip,
      points: event.points,
      timeSeconds: event.timeSeconds,
      streak: streak.current,
    );

    if (emit.isDone) return;

    emit(
      state.copyWith(
        improved: improved,
        status: ZipStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.zipClearedTitle,
          subtitle: '',
          timeSeconds: event.timeSeconds,
          improved: improved,
          points: event.points,
          replayDaily: true,
          replayRoute: '/zip',
          currentStreak: streak.current,
          longestStreak: streak.longest,
          gameId: GameIds.zip,
        ),
      ),
    );
  }

  Future<void> _onHint(ZipHint event, Emitter<ZipState> emit) async {
    await analytics.logHintUsed(
      gameId: GameIds.zip,
      hintsRemaining: event.hintsRemaining,
    );
  }

  Future<void> _onReset(ZipReset event, Emitter<ZipState> emit) async {
    await analytics.logGameReset(gameId: GameIds.zip);
  }
}
