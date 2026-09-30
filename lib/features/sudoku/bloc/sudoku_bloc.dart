import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../domain/entities/sudoku_puzzle.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/hint_quota_repository.dart';
import '../../../domain/sudoku/sudoku_hint_coach.dart';
import '../../../domain/streak_calculator.dart';
import '../../../domain/sudoku/sudoku_generator.dart';
import '../../../domain/sudoku/sudoku_rules.dart';
import '../../../domain/sudoku/sudoku_scoring.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/record_daily_clear.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/submit_score.dart';
import '../../results/results_args.dart';
import 'sudoku_event.dart';
import 'sudoku_state.dart';

class SudokuBloc extends Bloc<SudokuEvent, SudokuState> {
  SudokuBloc({
    required this.submitScore,
    required this.submitLeaderboardTime,
    required this.recordDailyClear,
    required this.getBestPoints,
    required this.getBestTimeSeconds,
    required this.analytics,
    required this.hintQuota,
    FutureOr<SudokuPuzzle> Function({required DateTime day})? generatePuzzle,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? wait,
    this.celebrationDuration = const Duration(seconds: 2),
    this.playPeriod = PlayPeriod.daily,
  }) : generatePuzzle =
           generatePuzzle ??
           (({required DateTime day}) => SudokuGenerator.generate(day: day)),
       _now = now ?? DateTime.now,
       _wait = wait ?? ((duration) => Future<void>.delayed(duration)),
       super(SudokuState.initial((now ?? DateTime.now)())) {
    on<SudokuStarted>(_onStarted);
    on<SudokuCellSelected>(_onCellSelected);
    on<SudokuDigitTapped>(_onDigitTapped);
    on<SudokuErase>(_onErase);
    on<SudokuNotesModeToggled>(_onNotesModeToggled);
    on<SudokuHint>(_onHint);
    on<SudokuDismissHint>(_onDismissHint);
    on<SudokuReset>(_onReset);
  }

  final SubmitScore submitScore;
  final SubmitLeaderboardTime submitLeaderboardTime;
  final RecordDailyClear recordDailyClear;
  final GetBestPoints getBestPoints;
  final GetBestTimeSeconds getBestTimeSeconds;
  final AnalyticsRepository analytics;
  final HintQuotaRepository hintQuota;
  final FutureOr<SudokuPuzzle> Function({required DateTime day}) generatePuzzle;
  final Duration celebrationDuration;
  final Duration playPeriod;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _wait;
  var _unitFlashGeneration = 0;
  static const _unitFlashDuration = Duration(milliseconds: 600);

  Future<void> _onStarted(
    SudokuStarted event,
    Emitter<SudokuState> emit,
  ) async {
    final seed = event.date ?? _now();
    final day = DateTime(seed.year, seed.month, seed.day);
    final playId = PlayPeriod.id(seed, playPeriod);
    final modeKey = 'sudoku_$playId';
    final alreadyCleared =
        getBestPoints(modeKey) > 0 || getBestTimeSeconds(modeKey) != null;

    emit(
      state.copyWith(
        status: SudokuStatus.loading,
        day: day,
        puzzle: null,
        grid: const [],
        notes: const [],
        selectedIndex: null,
        notesMode: false,
        startedAt: null,
        hintFlashIndex: null,
        rejectFlashIndex: null,
        activeCoachHint: null,
        showNoSimpleHint: false,
        unitFlashIndices: const <int>{},
        celebratedUnitIds: const <String>{},
        finished: false,
        points: null,
        timeSeconds: null,
        improved: null,
        resultsExtra: null,
      ),
    );

    final puzzle = await generatePuzzle(day: PlayPeriod.bucket(seed, playPeriod));
    if (emit.isDone) return;

    if (alreadyCleared) {
      emit(
        state.copyWith(
          status: SudokuStatus.locked,
          puzzle: puzzle,
          grid: List<int>.from(puzzle.solution),
          notes: SudokuRules.emptyNotes(puzzle.cellCount),
          finished: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: SudokuStatus.ready,
        puzzle: puzzle,
        grid: SudokuRules.initialGrid(puzzle),
        notes: SudokuRules.emptyNotes(puzzle.cellCount),
        startedAt: _now(),
        selectedIndex: null,
        notesMode: false,
        finished: false,
        hintsRemaining: hintQuota.remaining(GameIds.sudoku),
        activeCoachHint: null,
        showNoSimpleHint: false,
      ),
    );
    await analytics.logGameStarted(gameId: GameIds.sudoku);
  }

  void _onCellSelected(SudokuCellSelected event, Emitter<SudokuState> emit) {
    if (!_canPlay) return;
    final puzzle = state.puzzle;
    if (puzzle == null) return;
    final index = puzzle.indexOf(event.cell.row, event.cell.col);
    if (index < 0 || index >= puzzle.cellCount) return;
    emit(
      state.copyWith(
        selectedIndex: index,
        hintFlashIndex: null,
        rejectFlashIndex: null,
      ),
    );
  }

  Future<void> _onDigitTapped(
    SudokuDigitTapped event,
    Emitter<SudokuState> emit,
  ) async {
    if (!_canPlay) return;
    final puzzle = state.puzzle;
    final selected = state.selectedIndex;
    if (puzzle == null || selected == null) return;

    if (state.notesMode) {
      final toggled = SudokuRules.toggleNote(
        puzzle: puzzle,
        grid: state.grid,
        notes: state.notes,
        index: selected,
        digit: event.digit,
      );
      emit(
        state.copyWith(
          grid: toggled.grid,
          notes: toggled.notes,
          rejectFlashIndex: null,
          hintFlashIndex: null,
        ),
      );
      return;
    }

    final before = state.grid;
    final result = SudokuRules.tryPlaceDigit(
      puzzle: puzzle,
      grid: before,
      notes: state.notes,
      index: selected,
      digit: event.digit,
    );

    if (!result.accepted) {
      emit(
        state.copyWith(
          rejectFlashIndex: result.rejectIndex ?? selected,
          hintFlashIndex: null,
        ),
      );
      return;
    }

    final unitFlash = SudokuRules.newlyCompletedUnits(
      puzzle: puzzle,
      before: before,
      after: result.grid,
      alreadyCelebrated: state.celebratedUnitIds,
    );
    final celebrated = {...state.celebratedUnitIds, ...unitFlash.unitIds};

    final coach = state.activeCoachHint;
    final clearedCoach =
        coach != null &&
        selected == coach.targetIndex &&
        event.digit == coach.digit;

    emit(
      state.copyWith(
        grid: result.grid,
        notes: result.notes,
        rejectFlashIndex: null,
        hintFlashIndex: null,
        activeCoachHint: clearedCoach ? null : state.activeCoachHint,
        showNoSimpleHint: clearedCoach ? false : state.showNoSimpleHint,
        unitFlashIndices: unitFlash.cells,
        celebratedUnitIds: celebrated,
      ),
    );

    if (SudokuRules.isSolved(result.grid, puzzle.solution)) {
      await _finish(emit);
      return;
    }

    await _clearUnitFlashAfterDelay(emit, unitFlash.cells);
  }

  void _onErase(SudokuErase event, Emitter<SudokuState> emit) {
    if (!_canPlay) return;
    final puzzle = state.puzzle;
    final selected = state.selectedIndex;
    if (puzzle == null || selected == null) return;

    final erased = SudokuRules.eraseCell(
      puzzle: puzzle,
      grid: state.grid,
      notes: state.notes,
      index: selected,
    );
    emit(
      state.copyWith(
        grid: erased.grid,
        notes: erased.notes,
        rejectFlashIndex: null,
        hintFlashIndex: null,
        unitFlashIndices: const <int>{},
      ),
    );
  }

  void _onNotesModeToggled(
    SudokuNotesModeToggled event,
    Emitter<SudokuState> emit,
  ) {
    if (!_canPlay) return;
    emit(state.copyWith(notesMode: !state.notesMode, rejectFlashIndex: null));
  }

  Future<void> _onHint(SudokuHint event, Emitter<SudokuState> emit) async {
    if (!_canPlay) return;
    if (state.hintsRemaining <= 0) return;
    final puzzle = state.puzzle;
    if (puzzle == null) return;

    final coach = SudokuHintCoach.find(
      puzzle: puzzle,
      grid: state.grid,
      preferredIndex: state.selectedIndex,
    );
    if (coach == null) {
      emit(
        state.copyWith(
          showNoSimpleHint: true,
          activeCoachHint: null,
          rejectFlashIndex: null,
        ),
      );
      return;
    }

    final remaining = await hintQuota.tryConsume(GameIds.sudoku);
    emit(
      state.copyWith(
        hintsRemaining: remaining,
        activeCoachHint: coach,
        showNoSimpleHint: false,
        selectedIndex: coach.targetIndex,
        hintFlashIndex: null,
        rejectFlashIndex: null,
      ),
    );
    await analytics.logHintUsed(
      gameId: GameIds.sudoku,
      hintsRemaining: remaining,
    );
  }

  void _onDismissHint(SudokuDismissHint event, Emitter<SudokuState> emit) {
    emit(
      state.copyWith(
        activeCoachHint: null,
        showNoSimpleHint: false,
      ),
    );
  }

  void _onReset(SudokuReset event, Emitter<SudokuState> emit) {
    if (!_canPlay) return;
    final puzzle = state.puzzle;
    if (puzzle == null) return;

    emit(
      state.copyWith(
        grid: SudokuRules.initialGrid(puzzle),
        notes: SudokuRules.emptyNotes(puzzle.cellCount),
        selectedIndex: null,
        notesMode: false,
        hintFlashIndex: null,
        rejectFlashIndex: null,
        hintsRemaining: hintQuota.remaining(GameIds.sudoku),
        activeCoachHint: null,
        showNoSimpleHint: false,
        unitFlashIndices: const <int>{},
        celebratedUnitIds: const <String>{},
        finished: false,
        points: null,
        timeSeconds: null,
        improved: null,
        resultsExtra: null,
      ),
    );
    _unitFlashGeneration++;
    analytics.logGameReset(gameId: GameIds.sudoku);
  }

  bool get _canPlay =>
      !state.finished &&
      state.status == SudokuStatus.ready &&
      state.puzzle != null;

  Future<void> _clearUnitFlashAfterDelay(
    Emitter<SudokuState> emit,
    Set<int> unitFlash,
  ) async {
    if (unitFlash.isEmpty) return;
    final generation = ++_unitFlashGeneration;
    await _wait(_unitFlashDuration);
    if (emit.isDone || generation != _unitFlashGeneration) return;
    if (state.finished || state.status != SudokuStatus.ready) return;
    emit(state.copyWith(unitFlashIndices: const <int>{}));
  }

  Future<void> _finish(Emitter<SudokuState> emit) async {
    if (state.finished ||
        state.status == SudokuStatus.celebrating ||
        state.status == SudokuStatus.submitting ||
        state.status == SudokuStatus.navigating) {
      return;
    }
    final startedAt = state.startedAt;
    if (startedAt == null) return;

    final elapsed = _now().difference(startedAt).inSeconds;
    final points = SudokuScoring.pointsForElapsed(elapsed);

    emit(
      state.copyWith(
        finished: true,
        status: SudokuStatus.celebrating,
        points: points,
        timeSeconds: elapsed,
        hintFlashIndex: null,
        rejectFlashIndex: null,
        unitFlashIndices: const <int>{},
      ),
    );

    await _wait(celebrationDuration);
    if (emit.isDone) return;

    emit(state.copyWith(status: SudokuStatus.submitting));

    final dateId = StreakCalculator.dateId(state.day);
    final playId = PlayPeriod.id(
      PlayPeriod.isSubDaily(playPeriod)
          ? (state.startedAt ?? state.day)
          : state.day,
      playPeriod,
    );
    final improved = await submitScore(
      modeKey: 'sudoku_$playId',
      points: points,
      timeSeconds: elapsed,
    );

    if (improved) {
      try {
        await submitLeaderboardTime(
          gameId: GameIds.sudoku,
          timeSeconds: elapsed,
        );
      } catch (_) {
        // Best-effort remote sync; local score already saved.
      }
    }

    final streak = await recordDailyClear(
      gameId: GameIds.sudoku,
      dateId: dateId,
    );

    await analytics.logGameCompleted(
      gameId: GameIds.sudoku,
      points: points,
      timeSeconds: elapsed,
      streak: streak.current,
    );

    if (emit.isDone) return;

    emit(
      state.copyWith(
        improved: improved,
        status: SudokuStatus.navigating,
        resultsExtra: ResultsArgs(
          title: AppStrings.sudokuClearedTitle,
          subtitle: '',
          timeSeconds: elapsed,
          improved: improved,
          points: points,
          replayDaily: true,
          replayRoute: '/sudoku',
          currentStreak: streak.current,
          longestStreak: streak.longest,
          gameId: GameIds.sudoku,
        ),
      ),
    );
  }
}
