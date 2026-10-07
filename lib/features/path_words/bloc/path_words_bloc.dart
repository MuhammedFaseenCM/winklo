import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/sfx/sfx_id.dart';
import '../../../core/sfx/sfx_service.dart';
import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/cell.dart';
import '../../../domain/entities/in_progress_run.dart';
import '../../../domain/entities/path_words_puzzle.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/play_run_clock.dart';
import '../../../domain/path_words/path_words_rules.dart';
import '../../../domain/path_words/path_words_scoring.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/hint_quota_repository.dart';
import '../../../domain/repositories/in_progress_run_repository.dart';
import '../../../domain/streak_calculator.dart';
import '../../../domain/usecases/generate_daily_path_words.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
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
    required this.analytics,
    required this.hintQuota,
    required this.inProgressRuns,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? wait,
    this.celebrationDuration = const Duration(seconds: 2),
    this.playPeriod = PlayPeriod.daily,
    this.sfx,
  }) : _now = now ?? DateTime.now,
       _wait = wait ?? ((duration) => Future<void>.delayed(duration)),
       super(PathWordsState.initial((now ?? DateTime.now)())) {
    on<PathWordsStarted>(_onStarted);
    on<PathWordsPointerDown>(_onPointerDown);
    on<PathWordsPointerEnter>(_onPointerEnter);
    on<PathWordsPointerUp>(_onPointerUp);
    on<PathWordsUndo>(_onUndo);
    on<PathWordsHint>(_onHint);
    on<PathWordsReset>(_onReset);
    on<PathWordsPauseRun>(_onPauseRun);
    on<PathWordsResumeRun>(_onResumeRun);
  }

  final GenerateDailyPathWords generateDailyPathWords;
  final SubmitScore submitScore;
  final SubmitLeaderboardTime submitLeaderboardTime;
  final RecordDailyClear recordDailyClear;
  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final AnalyticsRepository analytics;
  final HintQuotaRepository hintQuota;
  final InProgressRunRepository inProgressRuns;
  final Duration celebrationDuration;
  final Duration playPeriod;
  final SfxService? sfx;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _wait;
  String? _playId;
  PlayRunClock? _clock;

  Future<void> _onStarted(
    PathWordsStarted event,
    Emitter<PathWordsState> emit,
  ) async {
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
        hintsRemaining: hintQuota.remaining(GameIds.pathWords),
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

      final draft = await inProgressRuns.load(
        gameId: GameIds.pathWords,
        playId: playId,
      );
      if (emit.isDone) return;

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
            hintsRemaining: hintQuota.remaining(GameIds.pathWords),
            hintRevealLength: restored.hintRevealLength,
            usedHintsThisRun: draft.usedHintsThisRun,
            activePath: restored.activePath,
            placedPaths: restored.placedPaths,
            completedTargetIds: restored.completedTargetIds,
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
        _clock = PlayRunClock.start(at: now);
        emit(
          state.copyWith(
            status: PathWordsStatus.ready,
            puzzle: puzzle,
            elapsedMs: 0,
            resumedAt: now,
            hintsRemaining: hintQuota.remaining(GameIds.pathWords),
            hintRevealLength: 0,
            usedHintsThisRun: false,
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
      }
      await analytics.logGameStarted(gameId: GameIds.pathWords);
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

    if (stroke.targetId != null) {
      unawaited(sfx?.play(SfxId.success) ?? Future<void>.value());
    }
    if (updatedCompleted.length >= puzzle.targets.length) {
      unawaited(sfx?.play(SfxId.clear) ?? Future<void>.value());
    }

    if (updatedCompleted.length >= puzzle.targets.length) {
      await _finish(emit);
    } else {
      await _persistDraft();
    }
  }

  void _onUndo(PathWordsUndo event, Emitter<PathWordsState> emit) {
    if (state.finished) return;
    if (state.status != PathWordsStatus.ready &&
        state.status != PathWordsStatus.playing) {
      return;
    }

    if (state.placedPaths.isNotEmpty) {
      final placed = state.placedPaths.sublist(0, state.placedPaths.length - 1);
      emit(
        state.copyWith(
          status: PathWordsStatus.playing,
          placedPaths: placed,
          completedTargetIds: {
            for (final stroke in placed)
              if (stroke.targetId != null) stroke.targetId!,
          },
          hintFlashCell: null,
          ruleTip: null,
        ),
      );
      unawaited(_persistDraft());
      return;
    }

    if (state.activePath.isEmpty) return;

    final undone = PathWordsRules.undoActive(state.activePath);
    emit(
      state.copyWith(
        status: PathWordsStatus.playing,
        activePath: undone,
        hintFlashCell: null,
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
    if (state.hintsRemaining <= 0) return;

    if (PathWordsRules.hasIncorrectStroke(state.placedPaths)) {
      final remaining = await hintQuota.tryConsume(GameIds.pathWords);
      emit(
        state.copyWith(
          placedPaths: PathWordsRules.withoutIncorrect(state.placedPaths),
          hintsRemaining: remaining,
          hintFlashCell: null,
          ruleTip: null,
          usedHintsThisRun: true,
        ),
      );
      await analytics.logHintUsed(
        gameId: GameIds.pathWords,
        hintsRemaining: remaining,
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

    final remaining = await hintQuota.tryConsume(GameIds.pathWords);
    emit(
      state.copyWith(
        hintsRemaining: remaining,
        hintFlashCell: path.last,
        hintRevealLength: path.length,
        usedHintsThisRun: true,
      ),
    );
    await analytics.logHintUsed(
      gameId: GameIds.pathWords,
      hintsRemaining: remaining,
    );
    await _persistDraft();
  }

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
        hintsRemaining: hintQuota.remaining(GameIds.pathWords),
        hintRevealLength: 0,
        hintFlashCell: null,
        errorMessage: null,
        ruleTip: null,
        usedHintsThisRun: false,
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
    final currentPlayId = PlayPeriod.id(now, playPeriod);
    final playId = _playId;
    if (playId != null && playId != currentPlayId) {
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
    final improved = await submitScore(
      modeKey: 'path_words_$playId',
      points: points,
      timeSeconds: elapsed,
    );

    final streak = await recordDailyClear(
      gameId: GameIds.pathWords,
      dateId: dateId,
    );

    try {
      await submitLeaderboardTime(
        gameId: GameIds.pathWords,
        timeSeconds: elapsed,
        usedHints: state.usedHintsThisRun,
        hadMistakes: false,
        currentStreak: streak.current,
      );
    } catch (_) {
      // Best-effort remote sync; local score already saved.
    }

    await analytics.logGameCompleted(
      gameId: GameIds.pathWords,
      points: points,
      timeSeconds: elapsed,
      streak: streak.current,
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
        ),
      ),
    );
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
        },
      ),
    );
  }

  ({
    List<Cell> activePath,
    List<PathWordsStroke> placedPaths,
    Set<String> completedTargetIds,
    int hintRevealLength,
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
    return (
      activePath: activePath,
      placedPaths: placedPaths,
      completedTargetIds: completedTargetIds,
      hintRevealLength: hintRevealLength,
    );
  }
}
