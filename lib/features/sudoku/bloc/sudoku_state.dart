import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/sudoku_puzzle.dart';
import '../../results/results_args.dart';

part 'sudoku_state.freezed.dart';

enum SudokuStatus {
  loading,
  ready,
  celebrating,
  submitting,
  navigating,
  locked,
}

@freezed
sealed class SudokuState with _$SudokuState {
  const factory SudokuState({
    required DateTime day,
    SudokuPuzzle? puzzle,
    @Default(<int>[]) List<int> grid,
    @Default(<Set<int>>[]) List<Set<int>> notes,
    int? selectedIndex,
    @Default(false) bool notesMode,
    @Default(SudokuStatus.loading) SudokuStatus status,
    DateTime? startedAt,
    int? hintFlashIndex,
    int? rejectFlashIndex,
    @Default(<int>{}) Set<int> unitFlashIndices,
    @Default(<String>{}) Set<String> celebratedUnitIds,
    @Default(false) bool finished,
    int? points,
    int? timeSeconds,
    bool? improved,
    ResultsArgs? resultsExtra,
  }) = _SudokuState;

  factory SudokuState.initial(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return SudokuState(day: day);
  }
}
