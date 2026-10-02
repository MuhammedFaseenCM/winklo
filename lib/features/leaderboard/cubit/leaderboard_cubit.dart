import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/failures.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import 'leaderboard_state.dart';

class LeaderboardCubit extends Cubit<LeaderboardState> {
  LeaderboardCubit({
    required WatchLeaderboard watchLeaderboard,
    required AuthRepository authRepository,
    String initialGameId = GameIds.zip,
  }) : _watchLeaderboard = watchLeaderboard,
       _authRepository = authRepository,
       super(
         LeaderboardState(
           gameId: initialGameId,
           currentUid: authRepository.currentUser?.uid,
         ),
       ) {
    _authSub = _authRepository.authStateChanges().listen(
      (user) {
        if (isClosed) return;
        emit(state.copyWith(currentUid: user?.uid));
      },
      onError: (Object error, StackTrace stack) {
        if (isClosed) return;
        // Ignore — usually permission-denied from users/{uid} during sign-out.
      },
    );
    _resubscribe();
  }

  final WatchLeaderboard _watchLeaderboard;
  final AuthRepository _authRepository;
  StreamSubscription? _boardSub;
  StreamSubscription? _authSub;

  void selectGame(String gameId) {
    if (gameId == state.gameId) return;
    if (gameId != GameIds.zip &&
        gameId != GameIds.pathWords &&
        gameId != GameIds.sudoku) {
      return;
    }
    emit(state.copyWith(gameId: gameId, status: LeaderboardStatus.loading));
    _resubscribe();
  }

  void selectPeriod(LeaderboardPeriod period) {
    if (period == state.period) return;
    emit(state.copyWith(period: period, status: LeaderboardStatus.loading));
    _resubscribe();
  }

  void retry() {
    emit(state.copyWith(status: LeaderboardStatus.loading, error: null));
    _resubscribe();
  }

  void _resubscribe() {
    unawaited(_boardSub?.cancel());
    _boardSub = _watchLeaderboard(gameId: state.gameId, period: state.period)
        .listen(
          (entries) {
            if (isClosed) return;
            emit(
              state.copyWith(
                status: LeaderboardStatus.ready,
                entries: entries,
                error: null,
              ),
            );
          },
          onError: (Object e) {
            if (isClosed) return;
            final message = e is Failure ? e.message : e.toString();
            emit(
              state.copyWith(status: LeaderboardStatus.failure, error: message),
            );
          },
        );
  }

  @override
  Future<void> close() async {
    await _boardSub?.cancel();
    await _authSub?.cancel();
    return super.close();
  }
}
