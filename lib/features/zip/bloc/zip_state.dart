import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/cell.dart';
import '../../../domain/entities/zip_level.dart';
import '../../../domain/play_period.dart';
import '../../results/results_args.dart';
import '../logic/daily_puzzle_generator.dart';

part 'zip_state.freezed.dart';

enum ZipStatus { initial, ready, celebrating, submitting, navigating, locked }

@freezed
sealed class ZipState with _$ZipState {
  const ZipState._();

  const factory ZipState({
    required DateTime day,
    required ZipLevel level,
    @Default(ZipStatus.ready) ZipStatus status,
    @Default(false) bool finished,
    @Default(false) bool usedHintsThisRun,
    @Default(0) int elapsedMs,
    DateTime? resumedAt,
    @Default(<Cell>[]) List<Cell> path,
    bool? improved,
    int? points,
    int? timeSeconds,
    ResultsArgs? resultsExtra,
  }) = _ZipState;

  factory ZipState.initial(DateTime now, {Duration period = PlayPeriod.daily}) {
    final day = DateTime(now.year, now.month, now.day);
    final level = DailyPuzzleGenerator.forDate(now, period: period);
    return ZipState(day: day, level: level, status: ZipStatus.initial);
  }

  bool get isClockRunning => resumedAt != null;
}
