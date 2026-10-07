import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/sudoku_puzzle.dart';
import '../../../domain/sudoku/sudoku_hint_coach.dart';
import '../../results/results_args.dart';

part 'sudoku_state.freezed.dart';

enum SudokuStatus {
  loading,
  ready,
  celebrating,
  submitting,
  navigating,
  locked,
  failed,
}

@freezed
sealed class SudokuState with _$SudokuState {
  const SudokuState._();

  const factory SudokuState({
    required DateTime day,
    SudokuPuzzle? puzzle,
    @Default(<int>[]) List<int> grid,
    @Default(<Set<int>>[]) List<Set<int>> notes,
    int? selectedIndex,
    @Default(false) bool notesMode,
    @Default(SudokuStatus.loading) SudokuStatus status,
    @Default(0) int elapsedMs,
    DateTime? resumedAt,
    int? hintFlashIndex,
    @Default(3) int hintsRemaining,
    SudokuCoachHint? activeCoachHint,
    @Default(false) bool showNoSimpleHint,
    @Default(false) bool usedHintsThisRun,
    @Default(false) bool hadMistakesThisRun,
    @Default(<int>{}) Set<int> errorIndices,
    @Default(<int>{}) Set<int> unitFlashIndices,
    @Default(<String>{}) Set<String> celebratedUnitIds,
    @Default(false) bool finished,
    String? errorMessage,
    int? points,
    int? timeSeconds,
    bool? improved,
    ResultsArgs? resultsExtra,
  }) = _SudokuState;

  factory SudokuState.initial(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return SudokuState(day: day);
  }

  int liveElapsedSeconds(DateTime now) {
    final resumed = resumedAt;
    final live = resumed == null
        ? 0
        : now.difference(resumed).inMilliseconds.clamp(0, 1 << 62);
    return (elapsedMs + live) ~/ 1000;
  }

  bool get isClockRunning => resumedAt != null;
}
