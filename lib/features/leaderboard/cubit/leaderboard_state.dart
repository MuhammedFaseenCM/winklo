import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';

part 'leaderboard_state.freezed.dart';

enum LeaderboardStatus { loading, ready, failure }

@freezed
sealed class LeaderboardState with _$LeaderboardState {
  const factory LeaderboardState({
    @Default(GameIds.zip) String gameId,
    @Default(LeaderboardPeriod.daily) LeaderboardPeriod period,
    @Default(LeaderboardStatus.loading) LeaderboardStatus status,
    @Default(<LeaderboardEntry>[]) List<LeaderboardEntry> entries,
    String? currentUid,
    String? error,
  }) = _LeaderboardState;
}
