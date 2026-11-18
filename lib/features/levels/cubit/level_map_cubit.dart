import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/game_ids.dart';
import '../../../domain/logic/level_catalog.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/repositories/leaderboard_repository.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';
import '../../../domain/usecases/submit_level_clear.dart';

enum LevelMapStatus { loading, ready, empty, unavailable }

class LevelMapState {
  const LevelMapState({
    this.status = LevelMapStatus.loading,
    this.map,
    this.boardLevelIds,
  });

  final LevelMapStatus status;

  /// Set when [status] is ready.
  final LevelMap? map;

  /// The levels the player's Levels board entry holds; null when unknown
  /// (not loaded yet, signed out, offline), in which case nothing is said
  /// about the board.
  final Set<String>? boardLevelIds;
}

/// The Levels tab's map: loads the published worlds once and rebuilds the
/// map whenever the player's level progress changes (a clear, a sync).
///
/// The board's level ids are re-read on every progress change, and a clear
/// the Worker takes ([SubmitLevelClear.accepted]) is added to them: that
/// change fires before the clear is posted, so its read can't see it.
class LevelMapCubit extends Cubit<LevelMapState> {
  LevelMapCubit({
    required this._worlds,
    required this._progress,
    this._leaderboard,
    SubmitLevelClear? submitLevelClear,
    this.game = GameIds.zip,
  }) : super(const LevelMapState()) {
    _changes = _progress.changes.listen((_) {
      // Also an account switch: the ids read so far may be another
      // player's, so nothing is said about the board until the read lands.
      _boardIds = null;
      _rebuild();
      unawaited(_loadBoardIds());
    });
    _accepted = submitLevelClear?.accepted.listen(_onAccepted);
  }

  final LevelWorldRepository _worlds;
  final LevelProgressRepository _progress;
  final LeaderboardRepository? _leaderboard;
  final String game;
  Set<String>? _boardIds;
  int _boardIdsLoad = 0;
  bool _boardIdsLoading = false;
  StreamSubscription<void>? _changes;
  StreamSubscription<String>? _accepted;
  LevelCatalog? _catalog;

  /// Loads the worlds (also the Retry action).
  Future<void> load() async {
    if (_catalog == null && state.status != LevelMapStatus.loading) {
      emit(const LevelMapState());
    }
    try {
      final catalog = await _worlds.catalog(game);
      if (isClosed) return;
      _catalog = catalog;
      _rebuild();
      await _loadBoardIds();
    } on LevelsUnavailable {
      if (isClosed || _catalog != null) return;
      emit(const LevelMapState(status: LevelMapStatus.unavailable));
    }
  }

  /// Reads which levels the board holds (the map doesn't wait for it); a
  /// failure leaves them unknown.
  Future<void> _loadBoardIds() async {
    final leaderboard = _leaderboard;
    if (leaderboard == null || _catalog == null) return;
    final load = ++_boardIdsLoad;
    _boardIdsLoading = true;
    Set<String>? ids;
    try {
      ids = await leaderboard.myBoardLevelIds(game);
    } catch (_) {
      ids = null;
    }
    if (isClosed || load != _boardIdsLoad) return;
    _boardIdsLoading = false;
    _boardIds = ids;
    _rebuild();
  }

  /// The Worker took a clear of [levelId]: the board holds it now. Unknown
  /// ids, or a read still running (it may have started before the post
  /// landed), are read again instead.
  void _onAccepted(String levelId) {
    if (isClosed) return;
    final ids = _boardIds;
    if (ids == null || _boardIdsLoading) {
      unawaited(_loadBoardIds());
      return;
    }
    if (ids.contains(levelId)) return;
    _boardIds = {...ids, levelId};
    _rebuild();
  }

  void _rebuild() {
    final catalog = _catalog;
    if (catalog == null || isClosed) return;
    if (catalog.isEmpty) {
      emit(const LevelMapState(status: LevelMapStatus.empty));
      return;
    }
    emit(
      LevelMapState(
        status: LevelMapStatus.ready,
        map: LevelMap.build(catalog, _progress.progress(game)),
        boardLevelIds: _boardIds,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    await _accepted?.cancel();
    return super.close();
  }
}
