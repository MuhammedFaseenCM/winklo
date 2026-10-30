import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../core/bloc/sequential.dart';
import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/in_progress_run.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/leaderboard_proof.dart';
import '../../../domain/entities/zip_level.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/hint_penalty.dart';
import '../../../domain/logic/level_catalog.dart';
import '../../../domain/logic/run_rollover.dart';
import '../../../domain/play_mode.dart';
import '../../../domain/play_period.dart';
import '../../../domain/play_run_clock.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/hint_quota_repository.dart';
import '../../../domain/repositories/in_progress_run_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/repositories/zip_level_repository.dart';
import '../../../domain/streak_calculator.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_clear_board.dart';
import '../../../domain/usecases/is_new_personal_best.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/record_level_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../../results/results_args.dart';
import '../logic/daily_puzzle_generator.dart';
import '../logic/zip_board_codec.dart';
import 'zip_event.dart';
import 'zip_state.dart';

class ZipBloc extends Bloc<ZipEvent, ZipState> {
  ZipBloc({
    required this.submitScore,
    required this.submitLeaderboardTime,
    required this.recordDailyClear,
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.getClearBoard,
    required this.isNewPersonalBest,
    required this.analytics,
    required this.hintQuota,
    required this.inProgressRuns,
    ZipLevelRepository? zipLevelRepository,
    Future<ZipLevel> Function(DateTime date, {Duration period})?
    fetchDailyLevel,
    this.ignoreDailyLock = false,
    this.playPeriod = PlayPeriod.daily,
    this.mode = PlayMode.daily,
    this.modeRecords,
    this.levelWorlds,
    this.recordLevelClear,
    ZipLevel Function(int seed)? practiceLevel,
    int Function()? newPracticeSeed,
    this.celebrationDuration = const Duration(seconds: 2),
    DateTime? now,
    DateTime Function()? clockNow,
    Future<void> Function(Duration duration)? wait,
  }) : assert(
         zipLevelRepository != null || fetchDailyLevel != null,
         'ZipBloc requires zipLevelRepository or fetchDailyLevel',
       ),
       assert(
         mode.isDaily || mode.isLevel || modeRecords != null,
         'Archive and practice runs keep their bests in modeRecords',
       ),
       assert(
         !mode.isLevel || (levelWorlds != null && recordLevelClear != null),
         'Level runs need levelWorlds and recordLevelClear',
       ),
       practiceLevel =
           practiceLevel ??
           ((seed) => DailyPuzzleGenerator.practice(seed: seed)),
       _newPracticeSeed = newPracticeSeed ?? (() => Random().nextInt(1 << 31)),
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
    // One at a time: each hint costs time, so none may race another.
    on<ZipHint>(_onHint, transformer: sequential());
    on<ZipReset>(_onReset);
    on<ZipPauseRun>(_onPauseRun);
    on<ZipResumeRun>(_onResumeRun);
    on<ZipNewBoard>(_onNewBoard);
  }

  final SubmitScore submitScore;
  final SubmitLeaderboardTime submitLeaderboardTime;
  final RecordDailyClear recordDailyClear;
  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final GetClearBoard getClearBoard;
  final IsNewPersonalBest isNewPersonalBest;
  final AnalyticsRepository analytics;

  /// Where this mode counts its hints (the daily count for a daily).
  final HintQuotaRepository hintQuota;
  final InProgressRunRepository inProgressRuns;
  final Future<ZipLevel> Function(DateTime date, {Duration period})
  fetchDailyLevel;
  final bool ignoreDailyLock;
  final Duration playPeriod;
  final Duration celebrationDuration;

  /// Daily, archive or practice. Only daily runs touch streaks, boards, the
  /// daily best and the cleared lock.
  final PlayMode mode;

  /// Bests of archive and practice runs; required for those modes.
  final PlayModeRecordRepository? modeRecords;

  /// Where level runs find their board; required for level runs.
  final LevelWorldRepository? levelWorlds;

  /// Keeps a level clear's stars; required for level runs.
  final RecordLevelClear? recordLevelClear;

  /// The level on screen and where it sits on the map; null outside level
  /// runs and until the board has loaded. Read by the screen on rebuild; it
  /// is set before the ready state is emitted.
  LevelSlot? get levelSlot => _levelSlot;
  LevelSlot? _levelSlot;

  /// Builds a practice board from a seed.
  final ZipLevel Function(int seed) practiceLevel;
  final int Function() _newPracticeSeed;

  /// Seed of the practice board on screen, kept in its draft.
  int? _practiceSeed;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _wait;
  PlayRunClock? _clock;
  String? _playId;

  /// Period of the run on screen. Hints count against it, so a run left
  /// open over midnight keeps its own count.
  String get playId => _playId ?? PlayPeriod.id(state.day, playPeriod);

  /// Where this daily's best is stored, for showing it in review.
  String get clearModeKey => 'zip_${state.level.id}';

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
    if (!mode.isDaily) return _startOffDaily(emit);
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
      if (emit.isDone) return;
      emit(
        ZipState(
          day: day,
          level: level,
          status: ZipStatus.locked,
          finished: true,
          // The player's own winning path; the game falls back to the
          // level's solution when it is missing (clears before it was stored).
          path:
              ZipBoardCodec.decode(getClearBoard('zip_${level.id}')) ??
              const [],
        ),
      );
      return;
    }

    var draft = await inProgressRuns.load(gameId: GameIds.zip, playId: playId);
    if (emit.isDone) return;
    var keptHints = false;
    if (draft != null && !draft.isForBoard(level.fingerprint)) {
      // Ops replaced today's board; the saved path belongs to the old one.
      // Hints spent on it still count, as after a reset.
      keptHints = draft.usedHintsThisRun;
      await inProgressRuns.clear(gameId: GameIds.zip, playId: playId);
      if (emit.isDone) return;
      draft = null;
    }

    final now = _now();
    final path = draft == null ? const <Cell>[] : _pathFromDraft(draft);
    final hintsUsed = hintQuota.usedFor(GameIds.zip, playId);
    final clock = draft == null
        ? HintPenalty.startClock(at: now, mode: mode, hintsUsed: hintsUsed)
        : PlayRunClock.restore(elapsedMs: draft.elapsedMs).resume(at: now);
    _clock = clock;

    emit(
      ZipState(
        day: day,
        level: level,
        status: ZipStatus.ready,
        finished: false,
        usedHintsThisRun: draft?.usedHintsThisRun ?? keptHints,
        hintsUsed: hintsUsed,
        hintPenaltySeconds:
            draft?.hintPenaltySeconds ??
            HintPenalty.chargedSeconds(mode, hintsUsed: hintsUsed),
        elapsedMs: clock.elapsedMs,
        resumedAt: now,
        path: path,
      ),
    );
    // Save the kept flags under the new board straight away.
    if (keptHints) await _persistDraft();
    await analytics.logGameStarted(
      gameId: GameIds.zip,
      dayId: playId,
      resumed: draft != null,
    );
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
    if (!mode.isDaily) return _completeOffDaily(emit);

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

    final improved = isNewPersonalBest(
      gameId: GameIds.zip,
      playId: playId,
      timeSeconds: elapsed,
    );
    await submitScore(
      modeKey: 'zip_${state.level.id}',
      points: points,
      timeSeconds: elapsed,
      usedHints: state.usedHintsThisRun,
      hadMistakes: false,
      board: ZipBoardCodec.encode(state.path),
    );

    final streak = await recordDailyClear(
      gameId: GameIds.zip,
      dateId: StreakCalculator.dateId(state.day),
    );

    final proof = ZipLeaderboardProof(state.path);
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
        proof: proof,
      );
    } catch (_) {
      // Best-effort remote sync; local score already saved.
    }

    await analytics.logGameCompleted(
      gameId: GameIds.zip,
      points: points,
      timeSeconds: elapsed,
      streak: streak.current,
      dayId: playId,
      usedHints: state.usedHintsThisRun,
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
          hintPenaltySeconds: state.hintPenaltySeconds,
          day: state.day,
          leaderboardProof: proof,
        ),
      ),
    );
  }

  /// The game already revealed the cells; this spends the hint and adds
  /// its time to the run clock.
  Future<void> _onHint(ZipHint event, Emitter<ZipState> emit) async {
    if (state.finished || state.status != ZipStatus.ready) return;
    final spent = await spendHint(
      quota: hintQuota,
      mode: mode,
      gameId: GameIds.zip,
      playId: playId,
    );
    // The run may have finished meanwhile; its time is already posted.
    if (state.finished || state.status != ZipStatus.ready) return;
    final clock = (_clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs))
        .addPenalty(Duration(seconds: spent.penaltySeconds));
    _clock = clock;
    emit(
      state.copyWith(
        usedHintsThisRun: true,
        hintsUsed: spent.hintsUsed,
        hintPenaltySeconds: state.hintPenaltySeconds + spent.penaltySeconds,
        elapsedMs: clock.elapsedMs,
        resumedAt: clock.resumedAt,
      ),
    );
    await _persistDraft();
    await analytics.logHintUsed(
      gameId: GameIds.zip,
      hintsUsed: spent.hintsUsed,
      penaltySeconds: spent.penaltySeconds,
    );
  }

  /// Clears the path but not the run: the clock, the hints spent and the
  /// clean-run flag carry on, so Clear can't earn "Hint-free" back.
  Future<void> _onReset(ZipReset event, Emitter<ZipState> emit) async {
    emit(state.copyWith(path: const []));
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
    final playId = _playId;
    // A run left open over midnight finishes for its own day; one older than
    // that gives way to today's puzzle. Archive and practice runs have no
    // day to leave behind.
    if (mode.isDaily &&
        playId != null &&
        !canFinishRun(playId, now, playPeriod)) {
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

  Future<void> _onNewBoard(ZipNewBoard event, Emitter<ZipState> emit) async {
    if (!mode.isPractice) return;
    if (state.status == ZipStatus.celebrating ||
        state.status == ZipStatus.submitting ||
        state.status == ZipStatus.navigating) {
      return;
    }
    await _startOffDaily(emit, freshPractice: true);
  }

  /// Starts (or resumes) an archive, practice or level run. It never reads the
  /// daily lock or today's draft: the run has its own id ([PlayMode.runId]).
  Future<void> _startOffDaily(
    Emitter<ZipState> emit, {
    bool freshPractice = false,
  }) async {
    final runId = mode.runId(dailyPlayId: '');
    _playId = runId;
    _clock = null;
    _levelSlot = null;
    final today = _now();
    final day = mode.day ?? DateTime(today.year, today.month, today.day);
    emit(
      ZipState(
        day: day,
        level: ZipLevel(
          id: mode.isArchive
              ? 'daily_$runId'
              : mode.isLevel
              ? mode.levelId!
              : 'practice',
          size: 1,
          numbers: const {},
          walls: const [],
        ),
        status: ZipStatus.initial,
      ),
    );

    if (freshPractice) {
      await inProgressRuns.clear(gameId: GameIds.zip, playId: runId);
      if (emit.isDone) return;
    }
    var draft = freshPractice
        ? null
        : await inProgressRuns.load(gameId: GameIds.zip, playId: runId);
    if (emit.isDone) return;

    late final ZipLevel level;
    try {
      if (mode.isArchive) {
        // Past days are always live and read by id, like the dailies.
        level = await fetchDailyLevel(day, period: PlayPeriod.daily);
      } else if (mode.isLevel) {
        final catalog = await levelWorlds!.catalog(GameIds.zip);
        final slot = catalog.slot(mode.levelId!);
        if (slot == null) {
          // A level that no longer exists can't be resumed either. Being
          // offline (LevelsUnavailable) keeps the draft for later.
          await inProgressRuns.clear(gameId: GameIds.zip, playId: runId);
          throw StateError('No level ${mode.levelId}');
        }
        level = slot.entry.zipLevel;
        _levelSlot = slot;
      } else {
        final saved = draft?.board['seed'];
        final seed = saved is num ? saved.toInt() : _newPracticeSeed();
        _practiceSeed = seed;
        level = practiceLevel(seed);
      }
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: ZipStatus.failed,
          errorMessage: mode.isLevel
              ? AppStrings.levelFailed
              : AppStrings.zipFailed,
        ),
      );
      return;
    }
    if (emit.isDone) return;

    if (draft != null && !draft.isForBoard(level.fingerprint)) {
      await inProgressRuns.clear(gameId: GameIds.zip, playId: runId);
      if (emit.isDone) return;
      draft = null;
    }
    if (draft == null && mode.isArchive) {
      // A fresh archive run starts with no hints spent.
      await modeRecords!.clearHints(GameIds.zip, runId);
      if (emit.isDone) return;
    }

    final now = _now();
    final hintsUsed = hintQuota.usedFor(GameIds.zip, runId);
    final clock = draft == null
        ? HintPenalty.startClock(at: now, mode: mode, hintsUsed: hintsUsed)
        : PlayRunClock.restore(elapsedMs: draft.elapsedMs).resume(at: now);
    _clock = clock;
    emit(
      ZipState(
        day: day,
        level: level,
        status: ZipStatus.ready,
        usedHintsThisRun: draft?.usedHintsThisRun ?? false,
        hintsUsed: hintsUsed,
        hintPenaltySeconds:
            draft?.hintPenaltySeconds ??
            HintPenalty.chargedSeconds(mode, hintsUsed: hintsUsed),
        elapsedMs: clock.elapsedMs,
        resumedAt: now,
        path: draft == null ? const <Cell>[] : _pathFromDraft(draft),
      ),
    );
    // Keep the practice seed, so leaving and coming back finds this board.
    if (draft == null && mode.isPractice) await _persistDraft();
    await analytics.logGameStarted(
      gameId: GameIds.zip,
      dayId: runId,
      resumed: draft != null,
    );
  }

  /// Finishes an archive, practice or level run: a local best (stars in the
  /// level progress for a level), no score, streak, leaderboard or daily
  /// best.
  Future<void> _completeOffDaily(Emitter<ZipState> emit) async {
    final now = _now();
    final clock = _clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs);
    final elapsed = clock.displayedSeconds(at: now);
    _clock = clock.pause(at: now);
    final points = (1000 - elapsed * 5).clamp(50, 1000);
    final runId = mode.runId(dailyPlayId: '');

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

    await inProgressRuns.clear(gameId: GameIds.zip, playId: runId);
    await _wait(celebrationDuration);
    if (emit.isDone) return;
    emit(state.copyWith(status: ZipStatus.submitting));

    if (mode.isLevel) {
      await _finishLevel(emit, elapsed: elapsed, points: points, runId: runId);
      return;
    }

    final records = modeRecords!;
    final best = await records.recordTime(mode.recordKey(GameIds.zip), elapsed);
    if (mode.isArchive) await records.clearHints(GameIds.zip, runId);

    await analytics.logGameCompleted(
      gameId: GameIds.zip,
      points: points,
      timeSeconds: elapsed,
      dayId: runId,
      usedHints: state.usedHintsThisRun,
    );
    if (emit.isDone) return;

    emit(
      state.copyWith(
        improved: best.improved,
        status: ZipStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.zipClearedTitle,
          subtitle: '',
          timeSeconds: elapsed,
          improved: best.improved,
          points: points,
          gameId: GameIds.zip,
          usedHints: state.usedHintsThisRun,
          hadMistakes: false,
          hintPenaltySeconds: state.hintPenaltySeconds,
          day: mode.day,
          local: LocalResultInfo(
            kind: mode.isArchive
                ? LocalResultKind.archive
                : LocalResultKind.practice,
            label: mode.isArchive
                ? AppStrings.archiveRunLabel(mode.day!)
                : AppStrings.practiceRunLabel,
            bestSeconds: best.best,
            againLocation: mode.isPractice
                ? PlayMode.practice.location('/zip')
                : null,
          ),
        ),
      ),
    );
  }

  /// A level clear: stars into the level progress, then Results with the
  /// goals and the next level. No score, streak, leaderboard or local best.
  Future<void> _finishLevel(
    Emitter<ZipState> emit, {
    required int elapsed,
    required int points,
    required String runId,
  }) async {
    final slot = _levelSlot!;
    final usedHints = state.usedHintsThisRun;
    final clear = await recordLevelClear!(
      game: GameIds.zip,
      slot: slot,
      usedHints: usedHints,
      seconds: elapsed,
    );
    await analytics.logGameCompleted(
      gameId: GameIds.zip,
      points: points,
      timeSeconds: elapsed,
      dayId: runId,
      usedHints: usedHints,
    );
    if (emit.isDone) return;

    final nextId = slot.nextId;
    emit(
      state.copyWith(
        improved: clear.improved,
        status: ZipStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.levelClearedTitle(slot.number),
          subtitle: '',
          timeSeconds: elapsed,
          improved: clear.improved,
          points: points,
          gameId: GameIds.zip,
          usedHints: usedHints,
          hadMistakes: false,
          hintPenaltySeconds: 0,
          local: LocalResultInfo(
            kind: LocalResultKind.level,
            label: AppStrings.levelRunLabel(slot.number, slot.world.theme),
            bestSeconds: clear.current.bestSeconds,
            againLocation: mode.location('/zip'),
            level: LevelResultInfo(
              runStars: clear.runStars,
              bestStars: clear.current.stars,
              previousStars: clear.previous?.stars,
              usedHints: usedHints,
              targetSeconds: slot.entry.targetSeconds,
              nextLocation: nextId == null
                  ? null
                  : PlayMode.level(nextId).location('/zip'),
              nextWorldTheme: slot.nextWorld?.theme,
            ),
          ),
        ),
      ),
    );
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
        hintPenaltySeconds: state.hintPenaltySeconds,
        boardFingerprint: state.level.fingerprint,
        board: {
          'path': [for (final cell in state.path) cell.toList()],
          if (mode.isPractice && _practiceSeed != null) 'seed': _practiceSeed,
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
