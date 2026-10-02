import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/cell.dart';

part 'path_words_event.freezed.dart';

@freezed
sealed class PathWordsEvent with _$PathWordsEvent {
  const factory PathWordsEvent.started({DateTime? date}) = PathWordsStarted;

  const factory PathWordsEvent.pointerDown(Cell cell) = PathWordsPointerDown;
  const factory PathWordsEvent.pointerEnter(Cell cell) = PathWordsPointerEnter;
  const factory PathWordsEvent.pointerUp() = PathWordsPointerUp;

  const factory PathWordsEvent.undo() = PathWordsUndo;
  const factory PathWordsEvent.hint() = PathWordsHint;
  const factory PathWordsEvent.reset() = PathWordsReset;
  const factory PathWordsEvent.pauseRun() = PathWordsPauseRun;
  const factory PathWordsEvent.resumeRun() = PathWordsResumeRun;
}
