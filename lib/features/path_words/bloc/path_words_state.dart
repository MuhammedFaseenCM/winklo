import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/cell.dart';
import '../../../domain/entities/path_words_puzzle.dart';
import '../../results/results_args.dart';

part 'path_words_state.freezed.dart';

enum PathWordsStatus {
  loading,
  ready,
  playing,
  celebrating,
  submitting,
  navigating,
  locked,
  failed,
}

@freezed
sealed class PathWordsState with _$PathWordsState {
  const factory PathWordsState({
    required DateTime day,
    PathWordsPuzzle? puzzle,
    @Default(PathWordsStatus.loading) PathWordsStatus status,
    @Default(<Cell>[]) List<Cell> activePath,
    @Default(<PathWordsStroke>[]) List<PathWordsStroke> placedPaths,
    @Default(<String>{}) Set<String> completedTargetIds,
    @Default(3) int hintsRemaining,
    @Default(0) int hintRevealLength,
    DateTime? startedAt,
    Cell? hintFlashCell,
    String? errorMessage,
    String? ruleTip,
    @Default(false) bool finished,
    int? points,
    int? timeSeconds,
    bool? improved,
    ResultsArgs? resultsExtra,
  }) = _PathWordsState;

  factory PathWordsState.initial(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return PathWordsState(day: day);
  }
}
