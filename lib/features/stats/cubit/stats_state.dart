import '../../../domain/entities/game_history.dart';
import '../../../domain/stats/game_stats.dart';

enum StatsStatus { loading, ready, failure }

class StatsState {
  const StatsState({
    this.status = StatsStatus.loading,
    this.history,
    this.stats = const {},
    this.unlocked = const {},
  });

  final StatsStatus status;

  /// The last history loaded; kept while a reload runs.
  final GameHistory? history;

  /// Per game id.
  final Map<String, GameStats> stats;

  /// Ids of the achievements earned.
  final Set<String> unlocked;

  /// Signed in, but only this device's clears could be counted.
  bool get remoteFailed => history?.remoteFailed ?? false;

  StatsState copyWith({
    StatsStatus? status,
    GameHistory? history,
    Map<String, GameStats>? stats,
    Set<String>? unlocked,
  }) {
    return StatsState(
      status: status ?? this.status,
      history: history ?? this.history,
      stats: stats ?? this.stats,
      unlocked: unlocked ?? this.unlocked,
    );
  }
}
