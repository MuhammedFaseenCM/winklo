import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../core/bloc/sequential.dart';
import '../../../core/haptics/haptics_service.dart';
import '../../../core/sfx/sfx_id.dart';
import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/cell.dart';
import '../../../domain/entities/in_progress_run.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/leaderboard_proof.dart';
import '../../../domain/entities/path_words_clear_summary.dart';
import '../../../domain/entities/path_words_puzzle.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/hint_penalty.dart';
import '../../../domain/logic/level_catalog.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/logic/run_rollover.dart';
import '../../../domain/path_words/path_words_generator.dart';
import '../../../domain/play_mode.dart';
import '../../../domain/play_period.dart';
import '../../../domain/play_run_clock.dart';
import '../../../domain/path_words/path_words_rules.dart';
import '../../../domain/path_words/path_words_scoring.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/hint_quota_repository.dart';
import '../../../domain/repositories/in_progress_run_repository.dart';
import '../../../domain/repositories/level_play_stats_repository.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/repositories/word_list_repository.dart';
import '../../../domain/streak_calculator.dart';
import '../../../domain/usecases/generate_daily_path_words.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/is_new_personal_best.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/record_level_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_level_clear.dart';
import '../../../domain/usecases/submit_score.dart';
import '../../results/results_args.dart';
import 'path_words_event.dart';
import 'path_words_state.dart';

class PathWordsBloc extends Bloc<PathWordsEvent, PathWordsState> {
  PathWordsBloc({
    required this.generateDailyPathWords,
    required this.submitScore,
    required this.submitLeaderboardTime,
    required this.recordDailyClear,
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.isNewPersonalBest,
    required this.analytics,
    required this.hintQuota,
    required this.inProgressRuns,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? wait,
    this.celebrationDuration = const Duration(seconds: 2),
    this.playPeriod = PlayPeriod.daily,
    this.sfx,
    this.haptics,
    this.wordList,
    this.mode = PlayMode.daily,
    this.modeRecords,
    this.levelWorlds,
    this.recordLevelClear,
    this.submitLevelClear,
    this.levelProgress,
    this.recordLevelPlay,
    this.practiceWords,
    PathWordsPuzzle Function(int seed, List<String> words)? practicePuzzle,
    int Function()? newPracticeSeed,
  }) : assert(
         mode.isDaily || mode.isLevel || modeRecords != null,
         'Archive and practice runs keep their bests in modeRecords',
       ),
       assert(
         !mode.isLevel || (levelWorlds != null && recordLevelClear != null),
         'Level runs need levelWorlds and recordLevelClear',
       ),
       practicePuzzle =
           practicePuzzle ??
           ((seed, words) =>
               PathWordsGenerator.practice(seed: seed, words: words)),
       _newPracticeSeed = newPracticeSeed ?? (() => Random().nextInt(1 << 31)),
       _now = now ?? DateTime.now,
       _wait = wait ?? ((duration) => Future<void>.delayed(duration)),
       super(PathWordsState.initial((now ?? DateTime.now)())) {
    on<PathWordsStarted>(_onStarted);
    on<PathWordsPointerDown>(_onPointerDown);
    on<PathWordsPointerEnter>(_onPointerEnter);
    on<PathWordsPointerUp>(_onPointerUp);
    on<PathWordsUndo>(_onUndo);
    // One at a time: each hint costs time, so a quick second tap must see
    // what the first revealed.
    on<PathWordsHint>(_onHint, transformer: sequential());
    on<PathWordsReset>(_onReset);
    on<PathWordsPauseRun>(_onPauseRun);
    on<PathWordsResumeRun>(_onResumeRun);
    on<PathWordsNewBoard>(_onNewBoard);
  }

  final GenerateDailyPathWords generateDailyPathWords;
  final SubmitScore submitScore;
  final SubmitLeaderboardTime submitLeaderboardTime;
  final RecordDailyClear recordDailyClear;
  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final IsNewPersonalBest isNewPersonalBest;
  final AnalyticsRepository analytics;
  final HintQuotaRepository hintQuota;
  final InProgressRunRepository inProgressRuns;
  final Duration celebrationDuration;
  final Duration playPeriod;
  final SfxService? sfx;
  final HapticsService? haptics;

  /// Bonus words come from its list; without it every non-target stroke is
  /// a wrong stroke, as before.
  final WordListRepository? wordList;

  /// Daily, archive or practice. Only daily runs touch streaks, boards, the
  /// daily best and the cleared lock; [hintQuota] is the mode's own.
  final PlayMode mode;

  /// Bests of archive and practice runs; required for those modes.
  final PlayModeRecordRepository? modeRecords;

  /// Where level runs find their board; required for level runs.
  final LevelWorldRepository? levelWorlds;

  /// Keeps a level clear's stars; required for level runs.
  final RecordLevelClear? recordLevelClear;

  /// Sends a level clear to the Levels board; null sends nothing. Never
  /// awaited: the network must not hold up the results.
  final SubmitLevelClear? submitLevelClear;

  /// The player's level progress, so a locked level can't be played (a
  /// link can name any published level). Null skips the check.
  final LevelProgressRepository? levelProgress;

  /// Counts level starts, clears and hints for the admin; null records
  /// nothing. Never awaited: a counter must not hold up play.
  final Future<void> Function({
    required String game,
    required String levelId,
    required LevelPlayEvent event,
  })?
  recordLevelPlay;

  void _countPlay(LevelPlayEvent event) {
    final slot = _levelSlot;
    final record = recordLevelPlay;
    if (!mode.isLevel || slot == null || record == null) return;
    unawaited(
      record(game: GameIds.pathWords, levelId: slot.entry.id, event: event),
    );
  }

  /// The level on screen and where it sits on the map; null outside level
  /// runs and until the board has loaded. Set before the ready state is
  /// emitted.
  LevelSlot? get levelSlot => _levelSlot;
  LevelSlot? _levelSlot;

  /// Practice words; the bundled list from [wordList] by default.
  final Future<List<String>> Function()? practiceWords;

  /// Builds a practice board from a seed.
  final PathWordsPuzzle Function(int seed, List<String> words) practicePuzzle;
  final int Function() _newPracticeSeed;

  /// Seed of the practice board on screen, kept in its draft.
  int? _practiceSeed;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _wait;
  String? _playId;
  PlayRunClock? _clock;

  /// Loaded in the background when a run starts; null until then.
  Set<String>? _bonusWordList;

  /// Bonus words are 4–8 letters (the bundled list's range).
  static const _bonusMinLength = 4;
  static const _bonusMaxLength = 8;

  /// Period of the run on screen; hints count against it, not the clock.
  String get _runPlayId => _playId ?? PlayPeriod.id(state.day, playPeriod);

  /// Where this daily's best is stored, for showing it in review.
  String get clearModeKey => 'path_words_$_runPlayId';

  Future<void> _onStarted(
    PathWordsStarted event,
    Emitter<PathWordsState> emit,
  ) async {
    if (!mode.isDaily) return _startOffDaily(emit);
    final seed = event.date ?? _now();
    final day = DateTime(seed.year, seed.month, seed.day);
    final playId = PlayPeriod.id(seed, playPeriod);
    _playId = playId;
    _clock = null;

    emit(
      state.copyWith(
        status: PathWordsStatus.loading,
        day: day,
        puzzle: null,
        activePath: const [],
        placedPaths: const [],
        completedTargetIds: const {},
        bonusWords: const [],
        hintsUsed: hintQuota.usedFor(GameIds.pathWords, _runPlayId),
        hintPenaltySeconds: 0,
        hintRevealLength: 0,
        usedHintsThisRun: false,
        elapsedMs: 0,
        resumedAt: null,
        hintFlashCell: null,
        errorMessage: null,
        finished: false,
        points: null,
        timeSeconds: null,
        improved: null,
        resultsExtra: null,
      ),
    );

    final modeKey = 'path_words_$playId';
    final alreadyCleared =
        getBestPoints(modeKey) > 0 || getBestTimeSeconds(modeKey) != null;

    try {
      final puzzle = await generateDailyPathWords(
        day: PlayPeriod.bucket(seed, playPeriod),
      );
      if (emit.isDone) return;

      if (alreadyCleared) {
        await inProgressRuns.clear(gameId: GameIds.pathWords, playId: playId);
        emit(
          state.copyWith(
            status: PathWordsStatus.locked,
            puzzle: puzzle,
            finished: true,
            completedTargetIds: {
              for (final target in puzzle.targets) target.id,
            },
            activePath: const [],
            placedPaths: const [],
            hintRevealLength: 0,
            hintFlashCell: null,
            errorMessage: null,
          ),
        );
        return;
      }

      unawaited(_loadBonusWordList());
      var draft = await inProgressRuns.load(
        gameId: GameIds.pathWords,
        playId: playId,
      );
      if (emit.isDone) return;
      var keptHints = false;
      if (draft != null && !draft.isForBoard(puzzle.fingerprint)) {
        // Ops replaced today's board; the saved words belong to the old one.
        // Hints spent on it still count, as after a reset.
        keptHints = draft.usedHintsThisRun;
        await inProgressRuns.clear(gameId: GameIds.pathWords, playId: playId);
        if (emit.isDone) return;
        draft = null;
      }

      final now = _now();
      if (draft != null) {
        final restored = _restoreFromDraft(draft);
        _clock = PlayRunClock.restore(
          elapsedMs: draft.elapsedMs,
        ).resume(at: now);
        emit(
          state.copyWith(
            status: PathWordsStatus.ready,
            puzzle: puzzle,
            elapsedMs: draft.elapsedMs,
            resumedAt: now,
            hintsUsed: hintQuota.usedFor(GameIds.pathWords, _runPlayId),
            hintPenaltySeconds: draft.hintPenaltySeconds,
            hintRevealLength: restored.hintRevealLength,
            usedHintsThisRun: draft.usedHintsThisRun,
            activePath: restored.activePath,
            placedPaths: restored.placedPaths,
            completedTargetIds: restored.completedTargetIds,
            bonusWords: restored.bonusWords,
            hintFlashCell: null,
            errorMessage: null,
            ruleTip: null,
            finished: false,
            points: null,
            timeSeconds: null,
            improved: null,
            resultsExtra: null,
          ),
        );
      } else {
        final hintsUsed = hintQuota.usedFor(GameIds.pathWords, _runPlayId);
        final clock = HintPenalty.startClock(
          at: now,
          mode: mode,
          hintsUsed: hintsUsed,
        );
        _clock = clock;
        emit(
          state.copyWith(
            status: PathWordsStatus.ready,
            puzzle: puzzle,
            elapsedMs: clock.elapsedMs,
            resumedAt: now,
            hintsUsed: hintsUsed,
            hintPenaltySeconds: HintPenalty.chargedSeconds(
              mode,
              hintsUsed: hintsUsed,
            ),
            hintRevealLength: 0,
            usedHintsThisRun: keptHints,
            activePath: const [],
            placedPaths: const [],
            completedTargetIds: const {},
            hintFlashCell: null,
            errorMessage: null,
            ruleTip: null,
            finished: false,
            points: null,
            timeSeconds: null,
            improved: null,
            resultsExtra: null,
          ),
        );
        // Save the kept flag under the new board straight away.
        if (keptHints) await _persistDraft();
      }
      await analytics.logGameStarted(
        gameId: GameIds.pathWords,
        dayId: playId,
        resumed: draft != null,
      );
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: PathWordsStatus.failed,
          errorMessage: AppStrings.pathWordsFailed,
        ),
      );
    }
  }

  void _onPointerDown(
    PathWordsPointerDown event,
    Emitter<PathWordsState> emit,
  ) {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    final puzzle = state.puzzle;
    if (puzzle == null) return;

    final locked = PathWordsRules.blockedCells(
      puzzle: puzzle,
      completedTargetIds: state.completedTargetIds,
      placedPaths: state.placedPaths,
    );

    // Resume only the in-progress stroke. A placed path stays put.
    if (state.activePath.isNotEmpty) {
      final path = state.activePath;
      if (event.cell == path.last) {
        if (state.hintFlashCell == null && state.ruleTip == null) return;
        emit(state.copyWith(hintFlashCell: null, ruleTip: null));
        return;
      }

      final popped = PathWordsRules.tryLifoBacktrack(
        path: path,
        candidate: event.cell,
      );
      if (popped != null) {
        emit(
          state.copyWith(
            status: PathWordsStatus.playing,
            activePath: popped,
            hintFlashCell: null,
            ruleTip: null,
          ),
        );
        return;
      }

      final extended = PathWordsRules.tryExtend(
        puzzle: puzzle,
        path: path,
        candidate: event.cell,
        locked: locked,
      );
      if (extended != null) {
        emit(
          state.copyWith(
            status: PathWordsStatus.playing,
            activePath: extended,
            hintFlashCell: null,
            ruleTip: null,
          ),
        );
        haptics?.play(HapticKind.tick);
        return;
      }

      final truncated = PathWordsRules.tryTruncate(
        path: path,
        candidate: event.cell,
      );
      if (truncated != null) {
        emit(
          state.copyWith(
            status: PathWordsStatus.playing,
            activePath: truncated,
            hintFlashCell: null,
            ruleTip: null,
          ),
        );
        return;
      }
    }

    final truncatedPlaced = PathWordsRules.truncatePlacedAt(
      placedPaths: state.placedPaths,
      cell: event.cell,
    );
    if (truncatedPlaced != null) {
      emit(
        state.copyWith(
          status: PathWordsStatus.playing,
          activePath: const [],
          placedPaths: truncatedPlaced,
          hintFlashCell: null,
          ruleTip: null,
        ),
      );
      return;
    }

    final begun = PathWordsRules.tryBegin(
      puzzle: puzzle,
      cell: event.cell,
      locked: locked,
      completedTargetIds: state.completedTargetIds,
    );

    if (begun == null) {
      // Invalid press (locked/blank) — keep any incomplete path as-is.
      if (state.hintFlashCell == null && state.ruleTip == null) return;
      emit(state.copyWith(hintFlashCell: null, ruleTip: null));
      return;
    }

    emit(
      state.copyWith(
        status: PathWordsStatus.playing,
        activePath: begun,
        hintFlashCell: null,
        ruleTip: null,
      ),
    );
    haptics?.play(HapticKind.tick);
  }

  void _onPointerEnter(
    PathWordsPointerEnter event,
    Emitter<PathWordsState> emit,
  ) {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    final puzzle = state.puzzle;
    if (puzzle == null) return;
    if (state.activePath.isEmpty) return;

    final locked = PathWordsRules.blockedCells(
      puzzle: puzzle,
      completedTargetIds: state.completedTargetIds,
      placedPaths: state.placedPaths,
    );
    final popped = PathWordsRules.tryLifoBacktrack(
      path: state.activePath,
      candidate: event.cell,
    );
    if (popped != null) {
      emit(
        state.copyWith(
          status: PathWordsStatus.playing,
          activePath: popped,
          hintFlashCell: null,
        ),
      );
      return;
    }

    final next = PathWordsRules.tryExtend(
      puzzle: puzzle,
      path: state.activePath,
      candidate: event.cell,
      locked: locked,
    );
    if (next == null) return;

    final grew = next.length > state.activePath.length;
    emit(
      state.copyWith(
        status: PathWordsStatus.playing,
        activePath: next,
        hintFlashCell: null,
      ),
    );
    if (grew) {
      unawaited(sfx?.play(SfxId.tap) ?? Future<void>.value());
      haptics?.play(HapticKind.tick);
    }
  }

  Future<void> _onPointerUp(
    PathWordsPointerUp event,
    Emitter<PathWordsState> emit,
  ) async {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    final puzzle = state.puzzle;
    if (puzzle == null) return;
    if (state.activePath.isEmpty) return;

    if (state.activePath.length < 2) {
      emit(
        state.copyWith(
          status: PathWordsStatus.playing,
          activePath: const [],
          hintFlashCell: null,
          ruleTip: null,
        ),
      );
      return;
    }

    final stroke = PathWordsRules.commitStroke(
      puzzle: puzzle,
      cells: state.activePath,
      completedTargetIds: state.completedTargetIds,
      colorIndex: PathWordsRules.nextUnusedColorIndex(
        puzzle: puzzle,
        completedTargetIds: state.completedTargetIds,
        placedPaths: state.placedPaths,
        paletteLength: 8,
      ),
    );

    // A real word that isn't a target: a bonus find, and the stroke clears
    // without counting as a wrong one.
    final bonus = stroke.isCorrect
        ? null
        : _bonusWordFor(puzzle, state.activePath);
    if (bonus != null) {
      emit(
        state.copyWith(
          status: PathWordsStatus.playing,
          activePath: const [],
          bonusWords: [...state.bonusWords, bonus],
          hintFlashCell: null,
          ruleTip: null,
        ),
      );
      haptics?.play(HapticKind.light);
      await _persistDraft();
      return;
    }

    final placed = [...state.placedPaths, stroke];
    final updatedCompleted = stroke.targetId == null
        ? state.completedTargetIds
        : {...state.completedTargetIds, stroke.targetId!};
    // Tip only after a finished stroke whose length matches a listed word
    // (never while the finger is still drawing).
    final failedAttempt =
        stroke.targetId == null &&
        PathWordsRules.looksLikeFailedWordAttempt(
          puzzle: puzzle,
          path: state.activePath,
          completedTargetIds: state.completedTargetIds,
        );
    final tip = failedAttempt ? AppStrings.pathWordsTipMatchList : null;

    emit(
      state.copyWith(
        status: PathWordsStatus.playing,
        activePath: const [],
        placedPaths: placed,
        completedTargetIds: updatedCompleted,
        hintFlashCell: null,
        hintRevealLength: stroke.isCorrect ? 0 : state.hintRevealLength,
        ruleTip: tip,
      ),
    );

    final solved = updatedCompleted.length >= puzzle.targets.length;
    if (stroke.targetId != null) {
      unawaited(sfx?.play(SfxId.success) ?? Future<void>.value());
    }
    if (solved) {
      unawaited(sfx?.play(SfxId.clear) ?? Future<void>.value());
      haptics?.play(HapticKind.win);
    } else if (stroke.targetId != null) {
      haptics?.play(HapticKind.success);
    }

    if (updatedCompleted.length >= puzzle.targets.length) {
      await _finish(emit);
    } else {
      await _persistDraft();
    }
  }

  /// Takes back the stroke being drawn (one cell at a time) or else the last
  /// wrong stroke. A found word is locked: undo never removes it (reset does).
  void _onUndo(PathWordsUndo event, Emitter<PathWordsState> emit) {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }

    if (state.activePath.isNotEmpty) {
      final undone = PathWordsRules.undoActive(state.activePath);
      emit(
        state.copyWith(
          status: PathWordsStatus.playing,
          activePath: undone,
          hintFlashCell: null,
        ),
      );
      unawaited(_persistDraft());
      return;
    }

    final wrong = PathWordsRules.lastIncorrectIndex(state.placedPaths);
    if (wrong == null) return;
    emit(
      state.copyWith(
        status: PathWordsStatus.playing,
        placedPaths: [...state.placedPaths]..removeAt(wrong),
        hintFlashCell: null,
        ruleTip: null,
      ),
    );
    unawaited(_persistDraft());
  }

  Future<void> _onHint(
    PathWordsHint event,
    Emitter<PathWordsState> emit,
  ) async {
    if (state.finished) return;
    final puzzle = state.puzzle;
    if (puzzle == null) return;

    if (PathWordsRules.hasIncorrectStroke(state.placedPaths)) {
      final spent = await _spendHint();
      if (spent == null) return;
      emit(
        state.copyWith(
          placedPaths: PathWordsRules.withoutIncorrect(state.placedPaths),
          hintsUsed: spent.hintsUsed,
          hintPenaltySeconds: state.hintPenaltySeconds + spent.penaltySeconds,
          elapsedMs: _clock!.elapsedMs,
          resumedAt: _clock!.resumedAt,
          hintFlashCell: null,
          ruleTip: null,
          usedHintsThisRun: true,
        ),
      );
      _countPlay(LevelPlayEvent.hint);
      await analytics.logHintUsed(
        gameId: GameIds.pathWords,
        hintsUsed: spent.hintsUsed,
        penaltySeconds: spent.penaltySeconds,
      );
      await _persistDraft();
      return;
    }

    final nextLength = state.hintRevealLength + 1;
    final path = PathWordsRules.hintedPath(
      puzzle: puzzle,
      completedTargetIds: state.completedTargetIds,
      revealedLength: nextLength,
    );
    if (path.isEmpty || path.length <= state.hintRevealLength) {
      return;
    }

    final spent = await _spendHint();
    if (spent == null) return;
    emit(
      state.copyWith(
        hintsUsed: spent.hintsUsed,
        hintPenaltySeconds: state.hintPenaltySeconds + spent.penaltySeconds,
        elapsedMs: _clock!.elapsedMs,
        resumedAt: _clock!.resumedAt,
        hintFlashCell: path.last,
        hintRevealLength: path.length,
        usedHintsThisRun: true,
      ),
    );
    _countPlay(LevelPlayEvent.hint);
    await analytics.logHintUsed(
      gameId: GameIds.pathWords,
      hintsUsed: spent.hintsUsed,
      penaltySeconds: spent.penaltySeconds,
    );
    await _persistDraft();
  }

  /// Spends a hint and adds its time to the run clock. Null when the run
  /// finished meanwhile: its time is already posted, so nothing is charged.
  Future<SpentHint?> _spendHint() async {
    final spent = await spendHint(
      quota: hintQuota,
      mode: mode,
      gameId: GameIds.pathWords,
      playId: _runPlayId,
    );
    if (state.finished) return null;
    _clock = (_clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs))
        .addPenalty(Duration(seconds: spent.penaltySeconds));
    return spent;
  }

  /// Clears the board but not the run: the clock, the hints spent and the
  /// clean-run flag carry on, so a reset can't earn "Hint-free" back.
  void _onReset(PathWordsReset event, Emitter<PathWordsState> emit) {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    if (state.puzzle == null) return;

    emit(
      state.copyWith(
        status: PathWordsStatus.ready,
        activePath: const [],
        placedPaths: const [],
        completedTargetIds: const {},
        bonusWords: const [],
        hintRevealLength: 0,
        hintFlashCell: null,
        errorMessage: null,
        ruleTip: null,
        finished: false,
        points: null,
        timeSeconds: null,
        improved: null,
        resultsExtra: null,
      ),
    );
    unawaited(_persistDraft());
    analytics.logGameReset(gameId: GameIds.pathWords);
  }

  Future<void> _onPauseRun(
    PathWordsPauseRun event,
    Emitter<PathWordsState> emit,
  ) async {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    final clock = _clock;
    if (clock == null || !clock.isRunning) return;
    final now = _now();
    final paused = clock.pause(at: now);
    _clock = paused;
    emit(state.copyWith(elapsedMs: paused.elapsedMs, resumedAt: null));
    await _persistDraft();
  }

  Future<void> _onResumeRun(
    PathWordsResumeRun event,
    Emitter<PathWordsState> emit,
  ) async {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    final now = _now();
    final playId = _playId;
    // A run left open over midnight finishes for its own day; one older than
    // that gives way to today's puzzle. Archive and practice runs have no
    // day to leave behind.
    if (mode.isDaily &&
        playId != null &&
        !canFinishRun(playId, now, playPeriod)) {
      await inProgressRuns.clear(gameId: GameIds.pathWords, playId: playId);
      add(PathWordsEvent.started(date: now));
      return;
    }
    final clock = _clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs);
    if (clock.isRunning) return;
    final resumed = clock.resume(at: now);
    _clock = resumed;
    emit(state.copyWith(elapsedMs: resumed.elapsedMs, resumedAt: now));
  }

  Future<void> _finish(Emitter<PathWordsState> emit) async {
    if (state.finished ||
        state.status == PathWordsStatus.celebrating ||
        state.status == PathWordsStatus.submitting ||
        state.status == PathWordsStatus.navigating) {
      return;
    }
    if (!mode.isDaily) return _finishOffDaily(emit);
    final now = _now();
    final clock = _clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs);
    final elapsed = clock.displayedSeconds(at: now);
    _clock = clock.pause(at: now);
    final points = PathWordsScoring.pointsForElapsed(elapsed);
    final playId = _playId ?? PlayPeriod.id(state.day, playPeriod);

    emit(
      state.copyWith(
        finished: true,
        status: PathWordsStatus.celebrating,
        points: points,
        timeSeconds: elapsed,
        elapsedMs: _clock!.elapsedMs,
        resumedAt: null,
        hintFlashCell: null,
      ),
    );

    await inProgressRuns.clear(gameId: GameIds.pathWords, playId: playId);

    await _wait(celebrationDuration);
    if (emit.isDone) return;

    emit(state.copyWith(status: PathWordsStatus.submitting));

    final dateId = StreakCalculator.dateId(state.day);
    final improved = isNewPersonalBest(
      gameId: GameIds.pathWords,
      playId: playId,
      timeSeconds: elapsed,
    );
    await submitScore(
      modeKey: 'path_words_$playId',
      points: points,
      timeSeconds: elapsed,
      usedHints: state.usedHintsThisRun,
      hadMistakes: false,
      // Kept with the clear meta; they don't change the time or the flags.
      bonusWords: state.bonusWords.isEmpty ? null : state.bonusWords,
    );

    final streak = await recordDailyClear(
      gameId: GameIds.pathWords,
      dateId: dateId,
    );

    final puzzle = state.puzzle;
    final proof = puzzle == null
        ? null
        : PathWordsLeaderboardProof.fromRun(
            puzzle: puzzle,
            completedTargetIds: state.completedTargetIds,
            placedPaths: state.placedPaths,
          );
    try {
      await submitLeaderboardTime(
        gameId: GameIds.pathWords,
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
      gameId: GameIds.pathWords,
      points: points,
      timeSeconds: elapsed,
      streak: streak.current,
      dayId: _runPlayId,
      usedHints: state.usedHintsThisRun,
    );

    if (emit.isDone) return;

    emit(
      state.copyWith(
        improved: improved,
        status: PathWordsStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.pathWordsClearedTitle,
          subtitle: '',
          timeSeconds: elapsed,
          improved: improved,
          points: points,
          replayDaily: true,
          replayRoute: '/path-words',
          currentStreak: streak.current,
          longestStreak: streak.longest,
          gameId: GameIds.pathWords,
          usedHints: state.usedHintsThisRun,
          hadMistakes: false,
          hintPenaltySeconds: state.hintPenaltySeconds,
          day: state.day,
          leaderboardProof: proof,
          pathWords: _clearSummary(),
        ),
      ),
    );
  }

  Future<void> _onNewBoard(
    PathWordsNewBoard event,
    Emitter<PathWordsState> emit,
  ) async {
    if (!mode.isPractice) return;
    if (state.status == PathWordsStatus.celebrating ||
        state.status == PathWordsStatus.submitting ||
        state.status == PathWordsStatus.navigating) {
      return;
    }
    await _startOffDaily(emit, freshPractice: true);
  }

  /// Starts (or resumes) an archive or practice run. It never reads the
  /// daily lock or today's draft: the run has its own id ([PlayMode.runId]).
  Future<void> _startOffDaily(
    Emitter<PathWordsState> emit, {
    bool freshPractice = false,
  }) async {
    final runId = mode.runId(dailyPlayId: '');
    _playId = runId;
    _clock = null;
    _levelSlot = null;
    final today = _now();
    final day = mode.day ?? DateTime(today.year, today.month, today.day);
    emit(
      state.copyWith(
        status: PathWordsStatus.loading,
        day: day,
        puzzle: null,
        activePath: const [],
        placedPaths: const [],
        completedTargetIds: const {},
        bonusWords: const [],
        hintsUsed: hintQuota.usedFor(GameIds.pathWords, runId),
        hintPenaltySeconds: 0,
        hintRevealLength: 0,
        usedHintsThisRun: false,
        elapsedMs: 0,
        resumedAt: null,
        hintFlashCell: null,
        errorMessage: null,
        ruleTip: null,
        finished: false,
        points: null,
        timeSeconds: null,
        improved: null,
        resultsExtra: null,
      ),
    );

    var lockedLevel = false;
    try {
      if (freshPractice) {
        await inProgressRuns.clear(gameId: GameIds.pathWords, playId: runId);
        if (emit.isDone) return;
      }
      var draft = freshPractice
          ? null
          : await inProgressRuns.load(gameId: GameIds.pathWords, playId: runId);
      if (emit.isDone) return;

      final PathWordsPuzzle puzzle;
      if (mode.isArchive) {
        // Past days are always live and read by id, like the dailies.
        puzzle = await generateDailyPathWords(
          day: day,
          period: PlayPeriod.daily,
        );
      } else if (mode.isLevel) {
        final catalog = await levelWorlds!.catalog(GameIds.pathWords);
        final slot = catalog.slot(mode.levelId!);
        if (slot == null) {
          // A level that no longer exists can't be resumed either. Being
          // offline (LevelsUnavailable) keeps the draft for later.
          await inProgressRuns.clear(gameId: GameIds.pathWords, playId: runId);
          throw StateError('No level ${mode.levelId}');
        }
        final progress = levelProgress;
        if (progress != null &&
            !LevelMap.build(
              catalog,
              progress.progress(GameIds.pathWords),
            ).isPlayable(slot.entry.id)) {
          lockedLevel = true;
          throw StateError('Level ${mode.levelId} is locked');
        }
        puzzle = slot.entry.pathWordsPuzzle;
        _levelSlot = slot;
      } else {
        final saved = draft?.board['seed'];
        final seed = saved is num ? saved.toInt() : _newPracticeSeed();
        _practiceSeed = seed;
        final words =
            await (practiceWords?.call() ??
                wordList?.loadPracticeWords() ??
                Future<List<String>>.error(StateError('No practice words')));
        puzzle = practicePuzzle(seed, words);
      }
      if (emit.isDone) return;

      if (draft != null && !draft.isForBoard(puzzle.fingerprint)) {
        await inProgressRuns.clear(gameId: GameIds.pathWords, playId: runId);
        if (emit.isDone) return;
        draft = null;
      }
      if (draft == null && mode.isArchive) {
        // A fresh archive run starts with no hints spent.
        await modeRecords!.clearHints(GameIds.pathWords, runId);
        if (emit.isDone) return;
      }

      unawaited(_loadBonusWordList());
      final now = _now();
      final restored = draft == null ? null : _restoreFromDraft(draft);
      final hintsUsed = hintQuota.usedFor(GameIds.pathWords, runId);
      final clock = draft == null
          ? HintPenalty.startClock(at: now, mode: mode, hintsUsed: hintsUsed)
          : PlayRunClock.restore(elapsedMs: draft.elapsedMs).resume(at: now);
      _clock = clock;
      emit(
        state.copyWith(
          status: PathWordsStatus.ready,
          puzzle: puzzle,
          elapsedMs: clock.elapsedMs,
          resumedAt: now,
          hintsUsed: hintsUsed,
          hintPenaltySeconds:
              draft?.hintPenaltySeconds ??
              HintPenalty.chargedSeconds(mode, hintsUsed: hintsUsed),
          hintRevealLength: restored?.hintRevealLength ?? 0,
          usedHintsThisRun: draft?.usedHintsThisRun ?? false,
          activePath: restored?.activePath ?? const [],
          placedPaths: restored?.placedPaths ?? const [],
          completedTargetIds: restored?.completedTargetIds ?? const {},
          bonusWords: restored?.bonusWords ?? const [],
        ),
      );
      if (draft == null) _countPlay(LevelPlayEvent.start);
      // Keep the practice seed, so leaving and coming back finds this board.
      if (draft == null && mode.isPractice) await _persistDraft();
      await analytics.logGameStarted(
        gameId: GameIds.pathWords,
        dayId: runId,
        resumed: draft != null,
      );
    } catch (_) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: PathWordsStatus.failed,
          errorMessage: lockedLevel
              ? AppStrings.levelLockedMessage
              : mode.isLevel
              ? AppStrings.levelFailed
              : AppStrings.pathWordsFailed,
        ),
      );
    }
  }

  /// Finishes an archive, practice or level run: a local best (stars in the
  /// level progress for a level), no score, streak, leaderboard or daily
  /// best.
  Future<void> _finishOffDaily(Emitter<PathWordsState> emit) async {
    final now = _now();
    final clock = _clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs);
    final elapsed = clock.displayedSeconds(at: now);
    _clock = clock.pause(at: now);
    final points = PathWordsScoring.pointsForElapsed(elapsed);
    final runId = mode.runId(dailyPlayId: '');

    emit(
      state.copyWith(
        finished: true,
        status: PathWordsStatus.celebrating,
        points: points,
        timeSeconds: elapsed,
        elapsedMs: _clock!.elapsedMs,
        resumedAt: null,
        hintFlashCell: null,
      ),
    );

    await inProgressRuns.clear(gameId: GameIds.pathWords, playId: runId);
    await _wait(celebrationDuration);
    if (emit.isDone) return;
    emit(state.copyWith(status: PathWordsStatus.submitting));

    if (mode.isLevel) {
      await _finishLevel(emit, elapsed: elapsed, points: points, runId: runId);
      return;
    }

    final records = modeRecords!;
    final best = await records.recordTime(
      mode.recordKey(GameIds.pathWords),
      elapsed,
    );
    if (mode.isArchive) await records.clearHints(GameIds.pathWords, runId);

    await analytics.logGameCompleted(
      gameId: GameIds.pathWords,
      points: points,
      timeSeconds: elapsed,
      dayId: runId,
      usedHints: state.usedHintsThisRun,
    );
    if (emit.isDone) return;

    emit(
      state.copyWith(
        improved: best.improved,
        status: PathWordsStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.pathWordsClearedTitle,
          subtitle: '',
          timeSeconds: elapsed,
          improved: best.improved,
          points: points,
          gameId: GameIds.pathWords,
          usedHints: state.usedHintsThisRun,
          hadMistakes: false,
          hintPenaltySeconds: state.hintPenaltySeconds,
          day: mode.day,
          pathWords: _clearSummary(),
          local: LocalResultInfo(
            kind: mode.isArchive
                ? LocalResultKind.archive
                : LocalResultKind.practice,
            label: mode.isArchive
                ? AppStrings.archiveRunLabel(mode.day!)
                : AppStrings.practiceRunLabel,
            bestSeconds: best.best,
            againLocation: mode.isPractice
                ? PlayMode.practice.location('/path-words')
                : null,
          ),
        ),
      ),
    );
  }

  /// A level clear: stars into the level progress, then Results with the
  /// goals and the next level. No score, streak, leaderboard or local best.
  Future<void> _finishLevel(
    Emitter<PathWordsState> emit, {
    required int elapsed,
    required int points,
    required String runId,
  }) async {
    final slot = _levelSlot!;
    final puzzle = state.puzzle!;
    final usedHints = state.usedHintsThisRun;
    final clear = await recordLevelClear!(
      game: GameIds.pathWords,
      slot: slot,
      usedHints: usedHints,
      seconds: elapsed,
    );
    _countPlay(LevelPlayEvent.clear);
    final submit = submitLevelClear;
    if (submit != null) {
      unawaited(
        submit(
          game: GameIds.pathWords,
          levelId: slot.entry.id,
          stars: clear.runStars,
          timeSeconds: elapsed,
          usedHints: usedHints,
          proof: PathWordsLeaderboardProof.fromRun(
            puzzle: puzzle,
            completedTargetIds: state.completedTargetIds,
            placedPaths: state.placedPaths,
          ),
          improved: clear.improved,
        ),
      );
    }
    await analytics.logGameCompleted(
      gameId: GameIds.pathWords,
      points: points,
      timeSeconds: elapsed,
      dayId: runId,
      usedHints: usedHints,
    );
    if (emit.isDone) return;

    emit(
      state.copyWith(
        improved: clear.improved,
        status: PathWordsStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.levelClearedTitle(slot.number),
          subtitle: '',
          timeSeconds: elapsed,
          improved: clear.improved,
          points: points,
          gameId: GameIds.pathWords,
          usedHints: usedHints,
          hadMistakes: false,
          hintPenaltySeconds: 0,
          pathWords: _clearSummary(
            theme: AppStrings.levelWorldDisplayName(slot.world),
          ),
          local: LocalResultInfo(
            kind: LocalResultKind.level,
            label: AppStrings.levelRunLabel(
              slot.number,
              AppStrings.levelWorldDisplayName(slot.world),
            ),
            bestSeconds: clear.current.bestSeconds,
            againLocation: mode.location('/path-words'),
            level: LevelResultInfo(
              runStars: clear.runStars,
              bestStars: clear.current.stars,
              previousStars: clear.previous?.stars,
              usedHints: usedHints,
              targetSeconds: slot.entry.targetSeconds,
              nextLevelId: slot.nextId,
              nextWorldName: slot.nextWorld == null
                  ? null
                  : AppStrings.levelWorldDisplayName(slot.nextWorld!),
              game: GameIds.pathWords,
            ),
          ),
        ),
      ),
    );
  }

  /// [theme] overrides the puzzle's: a level board has none of its own, so
  /// a level clear passes its world's name (the category).
  PathWordsClearSummary? _clearSummary({String? theme}) {
    final puzzle = state.puzzle;
    if (puzzle == null) return null;
    return PathWordsClearSummary(
      theme: theme ?? puzzle.theme,
      words: [
        for (final target in PathWordsRules.orderedTargets(puzzle)) target.word,
      ],
      definitions: puzzle.definitions,
      bonusWords: state.bonusWords,
    );
  }

  Future<void> _loadBonusWordList() async {
    final source = wordList;
    if (source == null || _bonusWordList != null) return;
    try {
      _bonusWordList = await source.loadBonusWords();
    } catch (_) {
      // No bonus words this run; strokes behave as before.
    }
  }

  /// The word [cells] spell, when it is a real word of 4–8 letters that
  /// isn't a target and wasn't found as a bonus already; null otherwise.
  String? _bonusWordFor(PathWordsPuzzle puzzle, List<Cell> cells) {
    final list = _bonusWordList;
    if (list == null) return null;
    if (cells.length < _bonusMinLength || cells.length > _bonusMaxLength) {
      return null;
    }
    final spelled = PathWordsRules.spell(puzzle, cells).toLowerCase();
    if (!list.contains(spelled)) return null;
    if (state.bonusWords.contains(spelled)) return null;
    if (puzzle.targets.any((t) => t.word.toLowerCase() == spelled)) {
      return null;
    }
    return spelled;
  }

  Future<void> _persistDraft() async {
    final playId = _playId;
    if (playId == null) return;
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }
    final elapsedMs =
        (_clock ?? PlayRunClock.restore(elapsedMs: state.elapsedMs))
            .displayedMs(at: _now());
    await inProgressRuns.save(
      InProgressRun(
        gameId: GameIds.pathWords,
        playId: playId,
        elapsedMs: elapsedMs,
        usedHintsThisRun: state.usedHintsThisRun,
        hintPenaltySeconds: state.hintPenaltySeconds,
        boardFingerprint: state.puzzle?.fingerprint,
        board: {
          'activePath': [for (final cell in state.activePath) cell.toList()],
          'placedPaths': [
            for (final stroke in state.placedPaths)
              {
                'cells': [for (final cell in stroke.cells) cell.toList()],
                'colorIndex': stroke.colorIndex,
                if (stroke.targetId != null) 'targetId': stroke.targetId,
              },
          ],
          'completedTargetIds': state.completedTargetIds.toList(),
          'hintRevealLength': state.hintRevealLength,
          if (state.bonusWords.isNotEmpty) 'bonusWords': state.bonusWords,
          if (mode.isPractice && _practiceSeed != null) 'seed': _practiceSeed,
        },
      ),
    );
  }

  ({
    List<Cell> activePath,
    List<PathWordsStroke> placedPaths,
    Set<String> completedTargetIds,
    int hintRevealLength,
    List<String> bonusWords,
  })
  _restoreFromDraft(InProgressRun draft) {
    final board = draft.board;
    final activeRaw = board['activePath'];
    final placedRaw = board['placedPaths'];
    final completedRaw = board['completedTargetIds'];
    final activePath = <Cell>[
      if (activeRaw is List)
        for (final entry in activeRaw) Cell.fromJson(entry),
    ];
    final placedPaths = <PathWordsStroke>[
      if (placedRaw is List)
        for (final entry in placedRaw)
          if (entry is Map)
            PathWordsStroke(
              cells: [
                for (final cell in (entry['cells'] as List? ?? const []))
                  Cell.fromJson(cell),
              ],
              colorIndex: (entry['colorIndex'] as num?)?.toInt() ?? 0,
              targetId: entry['targetId'] as String?,
            ),
    ];
    final completedTargetIds = <String>{
      if (completedRaw is List)
        for (final id in completedRaw)
          if (id is String) id,
    };
    final hintRevealLength = (board['hintRevealLength'] as num?)?.toInt() ?? 0;
    final bonusRaw = board['bonusWords'];
    final bonusWords = <String>[
      if (bonusRaw is List)
        for (final word in bonusRaw)
          if (word is String) word,
    ];
    return (
      activePath: activePath,
      placedPaths: placedPaths,
      completedTargetIds: completedTargetIds,
      hintRevealLength: hintRevealLength,
      bonusWords: bonusWords,
    );
  }
}
