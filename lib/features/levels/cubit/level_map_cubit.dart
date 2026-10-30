import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/game_ids.dart';
import '../../../domain/logic/level_catalog.dart';
import '../../../domain/logic/level_map.dart';
import '../../../domain/repositories/level_progress_repository.dart';
import '../../../domain/repositories/level_world_repository.dart';

enum LevelMapStatus { loading, ready, empty, unavailable }

class LevelMapState {
  const LevelMapState({this.status = LevelMapStatus.loading, this.map});

  final LevelMapStatus status;

  /// Set when [status] is ready.
  final LevelMap? map;
}

/// The Levels tab's map: loads the published worlds once and rebuilds the
/// map whenever the player's level progress changes (a clear, a sync).
class LevelMapCubit extends Cubit<LevelMapState> {
  LevelMapCubit({
    required this._worlds,
    required this._progress,
    this.game = GameIds.zip,
  }) : super(const LevelMapState()) {
    _changes = _progress.changes.listen((_) => _rebuild());
  }

  final LevelWorldRepository _worlds;
  final LevelProgressRepository _progress;
  final String game;
  StreamSubscription<void>? _changes;
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
    } on LevelsUnavailable {
      if (isClosed || _catalog != null) return;
      emit(const LevelMapState(status: LevelMapStatus.unavailable));
    }
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
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    return super.close();
  }
}
