import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/app_update_decision.dart';
import '../../../domain/entities/zip_level.dart';
import '../../../domain/play_period.dart';
import '../../zip/logic/daily_puzzle_generator.dart';

part 'home_state.freezed.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState({
    required ZipLevel dailyLevel,
    required String dateId,
    @Default(0) int bestPoints,
    int? bestTimeSeconds,
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    @Default(false) bool isOnFreeze,
    @Default(true) bool freezeAvailable,
    @Default(0) int pathWordsBestPoints,
    int? pathWordsBestTimeSeconds,
    @Default(0) int pathWordsCurrentStreak,
    @Default(0) int pathWordsLongestStreak,
    @Default(false) bool pathWordsIsOnFreeze,
    @Default(true) bool pathWordsFreezeAvailable,
    @Default(0) int sudokuBestPoints,
    int? sudokuBestTimeSeconds,
    @Default(0) int sudokuCurrentStreak,
    @Default(0) int sudokuLongestStreak,
    @Default(false) bool sudokuIsOnFreeze,
    @Default(true) bool sudokuFreezeAvailable,
    @Default(AppUpdateStatus.none) AppUpdateStatus updateStatus,
    @Default('') String updateStoreUrl,
    @Default('') String updateCurrentLabel,
    @Default('') String updateRequiredLabel,
  }) = _HomeState;

  factory HomeState.initial(
    DateTime now, {
    Duration period = PlayPeriod.daily,
  }) {
    final level = DailyPuzzleGenerator.forDate(now, period: period);
    return HomeState(
      dailyLevel: level,
      dateId: DailyPuzzleGenerator.dateId(now, period: period),
    );
  }
}
