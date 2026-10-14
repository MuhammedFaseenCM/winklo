import 'package:freezed_annotation/freezed_annotation.dart';

part 'cleared_summary_state.freezed.dart';

@freezed
sealed class ClearedSummaryState with _$ClearedSummaryState {
  const factory ClearedSummaryState({
    int? timeSeconds,
    bool? usedHints,
    bool? hadMistakes,

    /// The player's place on that day's board; null while loading, signed
    /// out, or outside the top entries the board loads.
    int? rank,
  }) = _ClearedSummaryState;
}
