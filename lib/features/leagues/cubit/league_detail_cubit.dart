import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/league.dart';
import '../../../domain/failures.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';

enum LeagueDetailStatus { loading, ready, gone, failure }

class LeagueDetailState {
  const LeagueDetailState({
    this.status = LeagueDetailStatus.loading,
    this.league,
    this.members = const {},
    this.uid,
    this.busy = false,
    this.error,
  });

  final LeagueDetailStatus status;
  final League? league;

  /// Names and photos by uid; players with no entry yet are missing.
  final Map<String, LeagueMember> members;
  final String? uid;
  final bool busy;
  final String? error;

  bool get isOwner => league?.isOwner(uid) ?? false;

  LeagueDetailState copyWith({
    LeagueDetailStatus? status,
    League? Function()? league,
    Map<String, LeagueMember>? members,
    bool? busy,
    String? Function()? error,
  }) => LeagueDetailState(
    status: status ?? this.status,
    league: league != null ? league() : this.league,
    members: members ?? this.members,
    uid: uid,
    busy: busy ?? this.busy,
    error: error != null ? error() : this.error,
  );
}

/// One league: its members, and what its owner or a member can do.
class LeagueDetailCubit extends Cubit<LeagueDetailState> {
  LeagueDetailCubit({
    required this._leagueId,
    required LeagueRepository leagueRepository,
    required AuthRepository authRepository,
  }) : _leagues = leagueRepository,
       super(LeagueDetailState(uid: authRepository.currentUser?.uid)) {
    _watch();
  }

  final String _leagueId;
  final LeagueRepository _leagues;
  StreamSubscription? _sub;
  Set<String> _profilesFor = const {};

  /// Only the newest names lookup may land.
  int _profilesRequest = 0;

  void _watch() {
    unawaited(_sub?.cancel());
    _sub = _leagues
        .watchLeague(_leagueId)
        .listen(
          _onLeague,
          onError: (Object _) {
            if (isClosed) return;
            _profilesFor = const {};
            emit(state.copyWith(status: LeagueDetailStatus.failure));
          },
        );
  }

  void retry() {
    emit(state.copyWith(status: LeagueDetailStatus.loading));
    _watch();
  }

  Future<void> _onLeague(League? league) async {
    if (isClosed) return;
    // Deleted, or (after leaving or being removed) no longer mine to read.
    if (league == null || !league.hasMember(state.uid)) {
      emit(
        state.copyWith(status: LeagueDetailStatus.gone, league: () => league),
      );
      return;
    }
    emit(
      state.copyWith(status: LeagueDetailStatus.ready, league: () => league),
    );
    final uids = league.memberUids.toSet();
    if (uids.length == _profilesFor.length && uids.containsAll(_profilesFor)) {
      return;
    }
    _profilesFor = uids;
    final request = ++_profilesRequest;
    final members = await _leagues.memberProfiles(league.memberUids);
    if (isClosed || request != _profilesRequest) return;
    emit(state.copyWith(members: members));
  }

  Future<bool> _run(Future<void> Function(League league) action) async {
    final league = state.league;
    if (league == null || state.busy) return false;
    emit(state.copyWith(busy: true, error: () => null));
    try {
      await action(league);
      if (!isClosed) emit(state.copyWith(busy: false));
      return true;
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: () => e is Failure ? e.message : e.toString(),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> rename(String name) =>
      _run((league) => _leagues.rename(league.id, name));

  Future<bool> removeMember(String uid) =>
      _run((league) => _leagues.removeMember(league.id, uid));

  Future<bool> leave() => _run((league) => _leagues.leave(league.id));

  Future<bool> delete() => _run(_leagues.delete);

  void clearError() => emit(state.copyWith(error: () => null));

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
