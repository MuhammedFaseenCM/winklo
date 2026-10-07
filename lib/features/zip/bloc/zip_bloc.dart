import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/in_progress_run.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/zip_level.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/play_run_clock.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/in_progress_run_repository.dart';
import '../../../domain/repositories/zip_level_repository.dart';
import '../../../domain/streak_calculator.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../../results/results_args.dart';
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
    required this.inProgressRuns,
    ZipLevelRepository? zipLevelRepository,
    Future<ZipLevel> Function(DateTime date, {Duration period})?
    fetchDailyLevel,
    this.ignoreDailyLock = false,
    this.playPeriod = PlayPeriod.daily,
    this.celebrationDuration = const Duration(seconds: 2),
    DateTime? now,
    DateTime Function()? clockNow,
    Future<void> Function(Duration duration)? wait,
  }) : assert(
         zipLevelRepository != null || fetchDailyLevel != null,
         'ZipBloc requires zipLevelRepository or fetchDailyLevel',
       ),
       fetchDailyLevel =
           fetchDailyLevel ??
           ((date, {period = PlayPeriod.daily}) =>
               zipLevelRepository!.fetchDailyLevel(date, period: period)),
       _now = clockNow ?? (() => now ?? DateTime.now()),
       _wait = wait ?? ((duration) => Future<void>.delayed(duration)),
       super(
         _initialState(
           clockNow?.call() ?? now ?? DateTime.now(),
           playPeriod: playPeriod,
         ),
       ) {
    on<ZipStarted>(_onStarted);
    on<ZipPathChanged>(_onPathChanged);
    on<ZipCompleted>(_onCompleted);
    on<ZipHint>(_onHint);
    on<ZipReset>(_onReset);
    on<ZipPauseRun>(_onPauseRun);
    on<ZipResumeRun>(_onResumeRun);
  }

  final SubmitScore submitScore;
  final SubmitLeaderboardTime submitLeaderboardTime;
  final RecordDailyClear recordDailyClear;
  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final AnalyticsRepository analytics;
  final InProgressRunRepository inProgressRuns;
  final Future<ZipLevel> Function(DateTime date, {Duration period})
  fetchDailyLevel;
  final bool ignoreDailyLock;
  final Duration playPeriod;
  final Duration celebrationDuration;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _wait;
  PlayRunClock? _clock;
  String? _playId;

  static ZipState _initialState(DateTime now, {required Duration playPeriod}) {
    return ZipState.initial(now, period: playPeriod);
  }

  static bool _isCleared({
    required String modeKey,
    required GetBestPoints getBestPoints,
    required GetBestTimeSeconds getBestTimeSeconds,
  }) {
    return getBestPoints(modeKey) > 0 || getBestTimeSeconds(modeKey) != null;
  }

  Future<void> _onStarted(ZipStarted event, Emitter<ZipState> emit) async {
    final seed = event.date ?? _now();
    final day = DateTime(seed.year, seed.month, seed.day);
    final playId = PlayPeriod.id(seed, playPeriod);
    _playId = playId;
    _clock = null;

    // Reset board while fetching so retries leave a failed screen cleanly.
    if (state.status != ZipStatus.initial || state.day != day) {
      emit(
        ZipState(
          day: day,
          level: ZipLevel(
            id: 'daily_$playId',
            size: 1,
            numbers: const {},
            walls: const [],
          ),
          status: ZipStatus.initial,
        ),
      );
    }

    late final ZipLevel level;
    try {
      level = await fetchDailyLevel(seed, period: playPeriod);
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: ZipStatus.failed,
          errorMessage: AppStrings.zipFailed,
        ),
      );
      return;
    }
    if (emit.isDone) return;
    final cleared =
        !ignoreDailyLock &&
        _isCleared(
          modeKey: 'zip_${level.id}',
          getBestPoints: getBestPoints,
          getBestTimeSeconds: getBestTimeSeconds,
        );

    if (cleared) {
      await inProgressRuns.clear(gameId: GameIds.zip, playId: playId);
      emit(
        ZipState(
          day: day,
          level: level,
          status: ZipStatus.locked,
          finished: true,
        ),
      );
      return;
    }

    final draft = await inProgressRuns.load(
      gameId: GameIds.zip,
      playId: playId,
    );
    if (emit.isDone) return;

    final now = _now();
    final path = draft == null ? const <Cell>[] : _pathFromDraft(draft);
    _clock = draft == null
        ? PlayRunClock.start(at: now)
        : PlayRunClock.restore(elapsedMs: draft.elapsedMs).resume(at: now);

    emit(
      ZipState(
        day: day,
        level: level,
        status: ZipStatus.ready,
        finished: false,
        usedHintsThisRun: draft?.usedHintsThisRun ?? false,
        elapsedMs: draft?.elapsedMs ?? 0,
        resumedAt: now,
        path: path,
      ),
    );
    await analytics.logGameStarted(gameId: GameIds.zip);
  }

  Future<void> _onPathChanged(
    ZipPathChanged event,
    Emitter<ZipState> emit,
  ) async {
    if (state.finished || state.status != ZipStatus.ready) return;
    emit(state.copyWith(path: List<Cell>.from(event.path)));
    await _persistDraft();
  }

  Future<void> _onCompleted(ZipCompleted event, Emitter<ZipState> emit) async {
    if (state.finished || state.status != ZipStatus.ready) {
      return;
    }

    final now = _now();
    final clock = _clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs);
    final elapsed = clock.displayedSeconds(at: now);
    _clock = clock.pause(at: now);
    final points = (1000 - elapsed * 5).clamp(50, 1000);
    final playId = _playId ?? PlayPeriod.id(state.day, playPeriod);

    emit(
      state.copyWith(
        finished: true,
        status: ZipStatus.celebrating,
        points: points,
        timeSeconds: elapsed,
        elapsedMs: _clock!.elapsedMs,
        resumedAt: null,
      ),
    );

    await inProgressRuns.clear(gameId: GameIds.zip, playId: playId);

    await _wait(celebrationDuration);
    if (emit.isDone) return;

    emit(state.copyWith(status: ZipStatus.submitting));

    final improved = await submitScore(
      modeKey: 'zip_${state.level.id}',
      points: points,
      timeSeconds: elapsed,
      usedHints: state.usedHintsThisRun,
      hadMistakes: false,
    );

    final streak = await recordDailyClear(
      gameId: GameIds.zip,
      dateId: StreakCalculator.dateId(state.day),
    );

    try {
      await submitLeaderboardTime(
        gameId: GameIds.zip,
        timeSeconds: elapsed,
        usedHints: state.usedHintsThisRun,
        hadMistakes: false,
        currentStreak: streak.current,
        // The puzzle's day, not submit time (runs finished after midnight).
        dayId: leaderboardDayId(state.day),
        // Lets a successful submit mark this clear as posted for the sync.
        playId: playId,
      );
    } catch (_) {
      // Best-effort remote sync; local score already saved.
    }

    await analytics.logGameCompleted(
      gameId: GameIds.zip,
      points: points,
      timeSeconds: elapsed,
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
          timeSeconds: elapsed,
          improved: improved,
          points: points,
          replayDaily: true,
          replayRoute: '/zip',
          currentStreak: streak.current,
          longestStreak: streak.longest,
          gameId: GameIds.zip,
          usedHints: state.usedHintsThisRun,
          hadMistakes: false,
        ),
      ),
    );
  }

  Future<void> _onHint(ZipHint event, Emitter<ZipState> emit) async {
    emit(state.copyWith(usedHintsThisRun: true));
    await _persistDraft();
    await analytics.logHintUsed(
      gameId: GameIds.zip,
      hintsRemaining: event.hintsRemaining,
    );
  }

  Future<void> _onReset(ZipReset event, Emitter<ZipState> emit) async {
    emit(state.copyWith(usedHintsThisRun: false, path: const []));
    await _persistDraft();
    await analytics.logGameReset(gameId: GameIds.zip);
  }

  Future<void> _onPauseRun(ZipPauseRun event, Emitter<ZipState> emit) async {
    if (state.finished || state.status != ZipStatus.ready) return;
    final clock = _clock;
    if (clock == null || !clock.isRunning) return;
    final now = _now();
    final paused = clock.pause(at: now);
    _clock = paused;
    emit(state.copyWith(elapsedMs: paused.elapsedMs, resumedAt: null));
    await _persistDraft();
  }

  Future<void> _onResumeRun(ZipResumeRun event, Emitter<ZipState> emit) async {
    if (state.finished || state.status != ZipStatus.ready) return;
    final now = _now();
    final currentPlayId = PlayPeriod.id(now, playPeriod);
    final playId = _playId;
    if (playId != null && playId != currentPlayId) {
      await inProgressRuns.clear(gameId: GameIds.zip, playId: playId);
      add(ZipEvent.started(date: now));
      return;
    }
    final clock = _clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs);
    if (clock.isRunning) return;
    final resumed = clock.resume(at: now);
    _clock = resumed;
    emit(state.copyWith(elapsedMs: resumed.elapsedMs, resumedAt: now));
  }

  Future<void> _persistDraft() async {
    final playId = _playId;
    if (playId == null) return;
    if (state.finished || state.status != ZipStatus.ready) return;
    final elapsedMs =
        (_clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs))
            .displayedMs(at: _now());
    await inProgressRuns.save(
      InProgressRun(
        gameId: GameIds.zip,
        playId: playId,
        elapsedMs: elapsedMs,
        usedHintsThisRun: state.usedHintsThisRun,
        board: {
          'path': [for (final cell in state.path) cell.toList()],
        },
      ),
    );
  }

  List<Cell> _pathFromDraft(InProgressRun draft) {
    final raw = draft.board['path'];
    if (raw is! List) return const [];
    return [for (final entry in raw) Cell.fromJson(entry)];
  }
}
