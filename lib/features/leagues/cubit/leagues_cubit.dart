import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/league.dart';
import '../../../domain/failures.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';

enum LeaguesStatus { signedOut, loading, ready, failure }

class LeaguesState {
  const LeaguesState({
    this.status = LeaguesStatus.loading,
    this.leagues = const [],
    this.uid,
    this.busy = false,
    this.error,
  });

  final LeaguesStatus status;
  final List<League> leagues;
  final String? uid;

  /// A create is running.
  final bool busy;

  /// The last action's failure, for a snackbar.
  final String? error;

  LeaguesState copyWith({
    LeaguesStatus? status,
    List<League>? leagues,
    String? Function()? uid,
    bool? busy,
    String? Function()? error,
  }) => LeaguesState(
    status: status ?? this.status,
    leagues: leagues ?? this.leagues,
    uid: uid != null ? uid() : this.uid,
    busy: busy ?? this.busy,
    error: error != null ? error() : this.error,
  );
}

/// The signed-in player's leagues, and creating one.
class LeaguesCubit extends Cubit<LeaguesState> {
  LeaguesCubit({
    required LeagueRepository leagueRepository,
    required AuthRepository authRepository,
  }) : _leagues = leagueRepository,
       super(LeaguesState(uid: authRepository.currentUser?.uid)) {
    _authSub = authRepository.authStateChanges().listen((user) {
      if (isClosed || user?.uid == state.uid) return;
      emit(state.copyWith(uid: () => user?.uid));
      _watch();
    }, onError: (Object _) {});
    _watch();
  }

  final LeagueRepository _leagues;
  StreamSubscription? _authSub;
  StreamSubscription? _leaguesSub;

  void _watch() {
    unawaited(_leaguesSub?.cancel());
    _leaguesSub = null;
    final uid = state.uid;
    if (uid == null) {
      emit(state.copyWith(status: LeaguesStatus.signedOut, leagues: const []));
      return;
    }
    emit(state.copyWith(status: LeaguesStatus.loading));
    _leaguesSub = _leagues
        .watchMyLeagues(uid)
        .listen(
          (leagues) {
            if (isClosed) return;
            emit(state.copyWith(status: LeaguesStatus.ready, leagues: leagues));
          },
          onError: (Object _) {
            if (isClosed) return;
            emit(state.copyWith(status: LeaguesStatus.failure));
          },
        );
  }

  void retry() => _watch();

  /// The new league, or null when it failed ([LeaguesState.error] says why).
  Future<League?> create(String name) async {
    if (state.busy) return null;
    emit(state.copyWith(busy: true, error: () => null));
    try {
      final league = await _leagues.create(name);
      if (!isClosed) emit(state.copyWith(busy: false));
      return league;
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: () => e is Failure ? e.message : e.toString(),
          ),
        );
      }
      return null;
    }
  }

  void clearError() => emit(state.copyWith(error: () => null));

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    await _leaguesSub?.cancel();
    return super.close();
  }
}
