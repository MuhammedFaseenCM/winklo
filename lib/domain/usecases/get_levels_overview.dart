import '../game_ids.dart';
import '../logic/level_map.dart';
import '../repositories/level_progress_repository.dart';
import '../repositories/level_world_repository.dart';

/// One game's Levels at a glance: where the player goes next and the stars
/// earned so far.
class GameLevelsOverview {
  const GameLevelsOverview({
    required this.gameId,
    required this.nextLevelId,
    required this.nextNumber,
    required this.stars,
    required this.maxStars,
    required this.allCleared,
  });

  final String gameId;

  /// The current level; the last level once every one is cleared.
  final String nextLevelId;
  final int nextNumber;
  final int stars;
  final int maxStars;
  final bool allCleared;
}

/// Every game with Levels at a glance; a game whose worlds can't load is
/// left out.
class LevelsOverview {
  const LevelsOverview(this.games);

  final Map<String, GameLevelsOverview> games;

  GameLevelsOverview? of(String gameId) => games[gameId];

  int get totalStars => games.values.fold(0, (sum, g) => sum + g.stars);
}

/// Reads each Levels game's map (cached worlds plus the player's progress)
/// for the Levels intro and Home's Levels card.
class GetLevelsOverview {
  GetLevelsOverview(this._worlds, this._progress);

  final LevelWorldRepository _worlds;
  final LevelProgressRepository _progress;

  Future<LevelsOverview> call() async {
    final games = <String, GameLevelsOverview>{};
    for (final gameId in levelGameIds) {
      final LevelMap map;
      try {
        map = LevelMap.build(
          await _worlds.catalog(gameId),
          _progress.progress(gameId),
        );
      } on LevelsUnavailable {
        continue;
      }
      if (map.isEmpty) continue;
      final lastWorld = map.worlds.lastWhere((w) => w.nodes.isNotEmpty);
      final nextId = map.currentId ?? lastWorld.nodes.last.slot.entry.id;
      final next = map.node(nextId)!;
      games[gameId] = GameLevelsOverview(
        gameId: gameId,
        nextLevelId: nextId,
        nextNumber: next.slot.number,
        stars: map.stars,
        maxStars: map.maxStars,
        allCleared: map.currentId == null,
      );
    }
    return LevelsOverview(games);
  }
}
