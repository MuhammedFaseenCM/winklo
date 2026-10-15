import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/league.dart';
import '../../../domain/league_code.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';

enum JoinLeagueStatus {
  /// The link's code can't be a league code.
  badCode,
  signedOut,
  loading,

  /// Found, and the player isn't in it yet.
  found,
  alreadyMember,
  notFound,
  full,
  joining,
  joined,
  failure,
}

class JoinLeagueState {
  const JoinLeagueState({
    required this.code,
    this.status = JoinLeagueStatus.loading,
    this.league,
  });

  /// As typed or linked; normalised when it's a valid code.
  final String code;
  final JoinLeagueStatus status;
  final League? league;

  JoinLeagueState copyWith({JoinLeagueStatus? status, League? league}) =>
      JoinLeagueState(
        code: code,
        status: status ?? this.status,
        league: league ?? this.league,
      );
}

/// `/join/{code}`: looks the league up, then joins it.
class JoinLeagueCubit extends Cubit<JoinLeagueState> {
  JoinLeagueCubit({
    required String code,
    required LeagueRepository leagueRepository,
    required AuthRepository authRepository,
  }) : _leagues = leagueRepository,
       _auth = authRepository,
       super(
         JoinLeagueState(
           code: normalizeLeagueCode(code) ?? code,
           status: normalizeLeagueCode(code) == null
               ? JoinLeagueStatus.badCode
               : JoinLeagueStatus.loading,
         ),
       ) {
    if (state.status == JoinLeagueStatus.badCode) return;
    _authSub = authRepository.authStateChanges().listen(
      (_) => unawaited(_lookUp()),
      onError: (Object _) {},
    );
    unawaited(_lookUp());
  }

  final LeagueRepository _leagues;
  final AuthRepository _auth;
  StreamSubscription? _authSub;
  String? _lookedUpFor;

  Future<void> _lookUp() async {
    if (isClosed) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _lookedUpFor = null;
      emit(state.copyWith(status: JoinLeagueStatus.signedOut));
      return;
    }
    if (_lookedUpFor == uid) return;
    _lookedUpFor = uid;
    emit(state.copyWith(status: JoinLeagueStatus.loading));
    try {
      final league = await _leagues.findByCode(state.code);
      if (isClosed) return;
      if (league == null) {
        emit(state.copyWith(status: JoinLeagueStatus.notFound));
      } else if (league.hasMember(uid)) {
        emit(
          state.copyWith(
            status: JoinLeagueStatus.alreadyMember,
            league: league,
          ),
        );
      } else if (league.isFull) {
        emit(state.copyWith(status: JoinLeagueStatus.full, league: league));
      } else {
        emit(state.copyWith(status: JoinLeagueStatus.found, league: league));
      }
    } catch (_) {
      _lookedUpFor = null;
      if (!isClosed) emit(state.copyWith(status: JoinLeagueStatus.failure));
    }
  }

  void retry() {
    _lookedUpFor = null;
    unawaited(_lookUp());
  }

  Future<void> join() async {
    if (state.status != JoinLeagueStatus.found) return;
    emit(state.copyWith(status: JoinLeagueStatus.joining));
    try {
      final league = await _leagues.join(state.code);
      if (!isClosed) {
        emit(state.copyWith(status: JoinLeagueStatus.joined, league: league));
      }
    } on LeagueFailure catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: switch (e.problem) {
            LeagueProblem.notFound => JoinLeagueStatus.notFound,
            LeagueProblem.full => JoinLeagueStatus.full,
            LeagueProblem.signedOut => JoinLeagueStatus.signedOut,
          },
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: JoinLeagueStatus.failure));
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
