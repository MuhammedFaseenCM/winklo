import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/entities/league.dart';
import '../../../domain/failures.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import 'leaderboard_state.dart';

class LeaderboardCubit extends Cubit<LeaderboardState> {
  /// Without [leagueRepository] (the Results mini board) there is no league
  /// scope. [now] picks "today" for the day strip (tests).
  LeaderboardCubit({
    required WatchLeaderboard watchLeaderboard,
    required AuthRepository authRepository,
    this._leagueRepository,
    DateTime Function()? now,
    String initialGameId = GameIds.zip,
  }) : _watchLeaderboard = watchLeaderboard,
       _authRepository = authRepository,
       _now = now ?? DateTime.now,
       super(
         LeaderboardState(
           gameId: initialGameId,
           currentUid: authRepository.currentUser?.uid,
         ),
       ) {
    _authSub = _authRepository.authStateChanges().listen(
      (user) {
        if (isClosed) return;
        final uid = user?.uid;
        if (uid != state.currentUid) {
          emit(state.copyWith(currentUid: uid));
          _watchLeagues();
        }
      },
      onError: (Object error, StackTrace stack) {
        if (isClosed) return;
        // Ignore — usually permission-denied from users/{uid} during sign-out.
      },
    );
    _watchLeagues();
    _resubscribe();
  }

  final WatchLeaderboard _watchLeaderboard;
  final AuthRepository _authRepository;
  final LeagueRepository? _leagueRepository;
  final DateTime Function() _now;
  StreamSubscription? _boardSub;
  StreamSubscription? _authSub;
  StreamSubscription? _leaguesSub;

  /// Today's board day, then the 13 before it.
  List<String> get recentDayIds => recentLeaderboardDayIds(_now());

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

  /// Shows the daily board of [dayId] (`yyyy-MM-dd`); today's for null.
  void selectDay(String? dayId) {
    final today = leaderboardDayId(_now());
    final next = dayId == today ? null : dayId;
    if (next != null && !recentDayIds.contains(next)) return;
    if (next == state.dayId) return;
    final reload = state.period == LeaderboardPeriod.daily;
    emit(
      state.copyWith(
        dayId: next,
        status: reload ? LeaderboardStatus.loading : state.status,
      ),
    );
    if (reload) _resubscribe();
  }

  /// Shows only [leagueId]'s members; everyone for null. A league that hasn't
  /// loaded yet (a link right after joining) is picked once it does.
  void selectLeague(String? leagueId) {
    _pendingLeagueId = null;
    if (leagueId == state.leagueId) return;
    if (leagueId != null && !state.leagues.any((l) => l.id == leagueId)) {
      _pendingLeagueId = leagueId;
      return;
    }
    emit(state.copyWith(leagueId: leagueId, status: LeaderboardStatus.loading));
    _resubscribe();
  }

  String? _pendingLeagueId;

  void retry() {
    emit(state.copyWith(status: LeaderboardStatus.loading, error: null));
    _resubscribe();
  }

  void _watchLeagues() {
    unawaited(_leaguesSub?.cancel());
    _leaguesSub = null;
    final repo = _leagueRepository;
    final uid = state.currentUid;
    if (repo == null || uid == null) {
      _applyLeagues(const []);
      return;
    }
    _leaguesSub = repo
        .watchMyLeagues(uid)
        .listen(
          _applyLeagues,
          // The board still works without the picker.
          onError: (Object _) => _applyLeagues(const []),
        );
  }

  void _applyLeagues(List<League> leagues) {
    if (isClosed) return;
    final pending = _pendingLeagueId;
    if (pending != null && leagues.any((l) => l.id == pending)) {
      _pendingLeagueId = null;
      emit(
        state.copyWith(
          leagues: leagues,
          leagueId: pending,
          status: LeaderboardStatus.loading,
        ),
      );
      _resubscribe();
      return;
    }
    final previous = state.league;
    final selected = state.leagueId;
    final stillMine = selected == null || leagues.any((l) => l.id == selected);
    emit(
      state.copyWith(
        leagues: leagues,
        leagueId: stillMine ? selected : null,
        status: stillMine ? state.status : LeaderboardStatus.loading,
      ),
    );
    final current = state.league;
    // Left or deleted, or its members changed: reload the board.
    if (!stillMine ||
        (current != null &&
            !_sameMembers(previous?.memberUids, current.memberUids))) {
      _resubscribe();
    }
  }

  static bool _sameMembers(List<String>? a, List<String> b) {
    if (a == null || a.length != b.length) return false;
    final set = a.toSet();
    return b.every(set.contains);
  }

  Stream<List<LeaderboardEntry>> _board() {
    final dayId = state.period == LeaderboardPeriod.daily ? state.dayId : null;
    final league = state.league;
    if (league != null) {
      return _watchLeaderboard.members(
        gameId: state.gameId,
        period: state.period,
        memberUids: league.memberUids,
        dayId: dayId,
      );
    }
    return _watchLeaderboard(
      gameId: state.gameId,
      period: state.period,
      dayId: dayId,
    );
  }

  void _resubscribe() {
    unawaited(_boardSub?.cancel());
    _boardSub = _board().listen(
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
        emit(state.copyWith(status: LeaderboardStatus.failure, error: message));
      },
    );
  }

  @override
  Future<void> close() async {
    await _boardSub?.cancel();
    await _authSub?.cancel();
    await _leaguesSub?.cancel();
    return super.close();
  }
}
