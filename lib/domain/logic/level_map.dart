import 'dart:math' as math;

import '../entities/level_progress.dart';
import '../entities/level_world.dart';
import 'level_catalog.dart';

/// Where a level stands for this player: cleared, next to play, or not yet open.
enum LevelNodeState { done, current, locked }

/// One level on the map.
class LevelMapNode {
  const LevelMapNode({required this.slot, required this.state, this.record});

  final LevelSlot slot;
  final LevelNodeState state;

  /// The level's best; null until it is cleared.
  final LevelRecord? record;

  bool get playable => state != LevelNodeState.locked;
  int get stars => math.min(record?.stars ?? 0, maxStars);

  /// Stars the level can give: 3, or 2 without a time goal.
  int get maxStars => slot.entry.targetSeconds == null ? 2 : 3;
}

/// One world on the map and its levels.
class LevelMapWorld {
  const LevelMapWorld({required this.world, required this.nodes});

  final LevelWorld world;
  final List<LevelMapNode> nodes;

  /// Levels open one by one, so a world is open once its first level is.
  bool get open => nodes.isNotEmpty && nodes.first.playable;
  int get stars => nodes.fold(0, (sum, n) => sum + n.stars);
  int get maxStars => nodes.fold(0, (sum, n) => sum + n.maxStars);

  /// The number of the world's last level; null for an empty world.
  int? get lastNumber => nodes.isEmpty ? null : nodes.last.slot.number;
}

/// The player's map: every published level, done, current or locked.
///
/// Levels open one by one: the current level is the first one, in map
/// order, that isn't cleared; a cleared level stays playable for replays.
/// A world with no levels is left out.
class LevelMap {
  LevelMap._(this.worlds, this.currentId, this._nodes);

  factory LevelMap.build(LevelCatalog catalog, LevelProgress progress) {
    final worlds = <LevelMapWorld>[];
    final byId = <String, LevelMapNode>{};
    String? currentId;
    for (final world in catalog.worlds) {
      if (world.levels.isEmpty) continue;
      final nodes = <LevelMapNode>[];
      for (final entry in world.levels) {
        final slot = catalog.slot(entry.id)!;
        final record = progress[entry.id];
        final LevelNodeState state;
        if (record != null) {
          state = LevelNodeState.done;
        } else if (currentId == null) {
          state = LevelNodeState.current;
          currentId = entry.id;
        } else {
          state = LevelNodeState.locked;
        }
        final node = LevelMapNode(slot: slot, state: state, record: record);
        nodes.add(node);
        byId[entry.id] = node;
      }
      worlds.add(LevelMapWorld(world: world, nodes: List.unmodifiable(nodes)));
    }
    return LevelMap._(List.unmodifiable(worlds), currentId, byId);
  }

  final List<LevelMapWorld> worlds;

  /// The next level to play; null when every level is cleared.
  final String? currentId;
  final Map<String, LevelMapNode> _nodes;

  LevelMapNode? node(String levelId) => _nodes[levelId];
  bool isPlayable(String levelId) => _nodes[levelId]?.playable ?? false;
  bool get isEmpty => _nodes.isEmpty;
  bool get allCleared => !isEmpty && currentId == null;
  int get stars => worlds.fold(0, (sum, w) => sum + w.stars);
  int get maxStars => worlds.fold(0, (sum, w) => sum + w.maxStars);
}
