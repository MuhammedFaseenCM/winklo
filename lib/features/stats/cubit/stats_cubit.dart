import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../core/dev_flags.dart';
import '../../../domain/achievements/achievement_rules.dart';
import '../../../domain/entities/game_history.dart';
import '../../../domain/logic/local_game_day.dart';
import '../../../domain/stats/game_stats.dart';
import '../../../domain/stats/preview_full_progress_history.dart';
import '../../../domain/usecases/load_game_history.dart';
import 'stats_state.dart';

/// Per-game stats and earned achievements from [LoadGameHistory].
///
/// Loads on creation, then reloads (debounced by [reloadDebounce]) on each
/// event of the `reloadOn` streams, e.g. local progress writes and sync
/// restores, so Profile's badges follow new clears.
class StatsCubit extends Cubit<StatsState> {
  StatsCubit({
    required this._loadHistory,
    Iterable<Stream<void>> reloadOn = const [],
    this.reloadDebounce = const Duration(milliseconds: 500),
    bool refreshRemote = false,
  }) : super(const StatsState()) {
    _reloadSubs = [
      for (final stream in reloadOn) stream.listen((_) => _scheduleReload()),
    ];
    unawaited(load(refresh: refreshRemote));
  }

  final LoadGameHistory _loadHistory;
  final Duration reloadDebounce;
  late final List<StreamSubscription<void>> _reloadSubs;
  Timer? _reloadTimer;

  /// [refresh] fetches the account's remote days again.
  Future<void> load({bool refresh = false}) async {
    try {
      final history = DevFlags.showFullProgressPreview
          ? previewFullProgressHistory()
          : await _loadHistory(refreshRemote: refresh);
      if (isClosed) return;
      emit(
        StatsState(
          status: StatsStatus.ready,
          history: history,
          stats: statsFor(history),
          unlocked: unlockedAchievementIds(history.achievementInput),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      // Keep showing the last good data when a reload fails.
      if (state.history == null) {
        emit(state.copyWith(status: StatsStatus.failure));
      }
    }
  }

  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(reloadDebounce, () => unawaited(load()));
  }

  /// [GameStats] for each daily game of [history].
  static Map<String, GameStats> statsFor(GameHistory history) => {
    for (final gameId in dailyProgressGameIds)
      gameId: computeGameStats(
        gameId: gameId,
        days: history.daysOf(gameId),
        streak: history.streakOf(gameId),
        today: history.today,
      ),
  };

  @override
  Future<void> close() async {
    _reloadTimer?.cancel();
    for (final sub in _reloadSubs) {
      await sub.cancel();
    }
    return super.close();
  }
}
