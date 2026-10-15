import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/game_ids.dart';

part 'leaderboard_state.freezed.dart';

enum LeaderboardStatus { loading, ready, failure }

@freezed
sealed class LeaderboardState with _$LeaderboardState {
  const LeaderboardState._();

  const factory LeaderboardState({
    @Default(GameIds.zip) String gameId,
    @Default(LeaderboardPeriod.daily) LeaderboardPeriod period,
    @Default(LeaderboardStatus.loading) LeaderboardStatus status,
    @Default(<LeaderboardEntry>[]) List<LeaderboardEntry> entries,
    String? currentUid,
    String? error,

    /// The daily board's day (`yyyy-MM-dd`); null is today. Past days are
    /// read-only snapshots of the same board.
    String? dayId,

    /// The league whose members the board shows; null is everyone.
    String? leagueId,

    /// The signed-in player's leagues, for the scope picker.
    @Default(<League>[]) List<League> leagues,
  }) = _LeaderboardState;

  /// The league picked in the scope picker, if it's still one of mine.
  League? get league {
    final id = leagueId;
    if (id == null) return null;
    for (final league in leagues) {
      if (league.id == id) return league;
    }
    return null;
  }
}
