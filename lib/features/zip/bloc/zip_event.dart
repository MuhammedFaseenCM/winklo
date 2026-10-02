import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/cell.dart';

part 'zip_event.freezed.dart';

@freezed
sealed class ZipEvent with _$ZipEvent {
  const factory ZipEvent.started({DateTime? date}) = ZipStarted;

  const factory ZipEvent.pathChanged({required List<Cell> path}) =
      ZipPathChanged;

  const factory ZipEvent.completed() = ZipCompleted;

  const factory ZipEvent.hint({required int hintsRemaining}) = ZipHint;

  const factory ZipEvent.reset() = ZipReset;

  const factory ZipEvent.pauseRun() = ZipPauseRun;

  const factory ZipEvent.resumeRun() = ZipResumeRun;
}
