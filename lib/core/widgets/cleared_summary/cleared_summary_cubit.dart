import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_clear_meta.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import 'cleared_summary_state.dart';

/// What a cleared daily shows when reopened: the run's time and flags from
/// this phone, and the player's rank from that day's live board.
class ClearedSummaryCubit extends Cubit<ClearedSummaryState> {
  ClearedSummaryCubit({
    required String gameId,
    required String modeKey,
    required DateTime day,
    required GetBestTimeSeconds getBestTimeSeconds,
    required GetClearMeta getClearMeta,
    required WatchLeaderboard watchLeaderboard,
    required AuthRepository authRepository,
  }) : super(_local(modeKey, getBestTimeSeconds, getClearMeta)) {
    final uid = authRepository.currentUser?.uid;
    if (uid == null) return;
    _boardSub =
        watchLeaderboard(
          gameId: gameId,
          period: LeaderboardPeriod.daily,
          dayId: leaderboardDayId(day),
        ).listen(
          (entries) {
            if (isClosed) return;
            final rank = entries.where((e) => e.uid == uid).firstOrNull?.rank;
            if (rank != state.rank) emit(state.copyWith(rank: rank));
          },
          // Offline or no Firebase: the summary just goes without a rank.
          onError: (Object _) {},
        );
  }

  static ClearedSummaryState _local(
    String modeKey,
    GetBestTimeSeconds getBestTimeSeconds,
    GetClearMeta getClearMeta,
  ) {
    final meta = getClearMeta(modeKey);
    return ClearedSummaryState(
      timeSeconds: getBestTimeSeconds(modeKey),
      usedHints: meta?.usedHints,
      hadMistakes: meta?.hadMistakes,
    );
  }

  StreamSubscription<void>? _boardSub;

  @override
  Future<void> close() async {
    await _boardSub?.cancel();
    return super.close();
  }
}
