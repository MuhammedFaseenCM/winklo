import '../logic/level_catalog.dart';

/// Levels could not be loaded from the server or from the cache.
class LevelsUnavailable implements Exception {
  const LevelsUnavailable(this.message);

  final String message;

  @override
  String toString() => 'LevelsUnavailable: $message';
}

/// The published worlds of a game's Levels.
abstract class LevelWorldRepository {
  /// Published worlds of [game] in order, from the server, else from the
  /// cache. Kept for the session; [refresh] reads again. Throws
  /// [LevelsUnavailable] when neither the server nor the cache has them.
  Future<LevelCatalog> catalog(String game, {bool refresh = false});
}
