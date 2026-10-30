import '../entities/level_world.dart';

/// Where one level sits on the map.
class LevelSlot {
  const LevelSlot({
    required this.world,
    required this.entry,
    required this.number,
    required this.indexInWorld,
    this.nextId,
    this.nextWorld,
  });

  final LevelWorld world;
  final LevelEntry entry;

  /// "Level 27": counted across every world before this one, from 1.
  final int number;
  final int indexInWorld;

  /// The level after this one; null on the last published level.
  final String? nextId;

  /// The world [nextId] starts, when it starts a new one; null otherwise.
  final LevelWorld? nextWorld;

  bool get opensNewWorld => nextWorld != null;
}

/// A game's published worlds in order, with every level numbered and found
/// by id. Numbers are worked out here, never stored.
class LevelCatalog {
  LevelCatalog(List<LevelWorld> worlds)
    : worlds = List.unmodifiable(
        [...worlds]..sort((a, b) => a.order.compareTo(b.order)),
      ) {
    final flat = <(LevelWorld, LevelEntry, int)>[
      for (final world in this.worlds)
        for (var i = 0; i < world.levels.length; i++)
          (world, world.levels[i], i),
    ];
    for (var n = 0; n < flat.length; n++) {
      final (world, entry, index) = flat[n];
      final next = n + 1 < flat.length ? flat[n + 1] : null;
      _slots[entry.id] = LevelSlot(
        world: world,
        entry: entry,
        number: n + 1,
        indexInWorld: index,
        nextId: next?.$2.id,
        nextWorld: next != null && !identical(next.$1, world) ? next.$1 : null,
      );
    }
  }

  final List<LevelWorld> worlds;
  final Map<String, LevelSlot> _slots = {};

  bool get isEmpty => _slots.isEmpty;
  int get levelCount => _slots.length;

  LevelSlot? slot(String levelId) => _slots[levelId];
}
