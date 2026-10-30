import '../../domain/entities/level_world.dart';
import '../../domain/logic/level_catalog.dart';
import '../../domain/repositories/level_world_repository.dart';
import '../clients/level_worlds_source.dart';

class LevelWorldRepositoryImpl implements LevelWorldRepository {
  /// [source] is null while Firebase isn't ready.
  LevelWorldRepositoryImpl(this._source);

  final LevelWorldsSource? _source;
  final Map<String, Future<LevelCatalog>> _loaded = {};

  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) {
    if (refresh) _loaded.remove(game);
    final kept = _loaded[game];
    if (kept != null) return kept;
    final future = _load(game);
    _loaded[game] = future;
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_loaded[game], future)) _loaded.remove(game);
      },
    );
    return future;
  }

  Future<LevelCatalog> _load(String game) async {
    final source = _source;
    if (source == null) throw const LevelsUnavailable('Firebase is not ready');
    List<LevelWorldDoc> docs;
    try {
      docs = await source.published(game, fromCache: false);
    } catch (_) {
      try {
        docs = await source.published(game, fromCache: true);
      } catch (e) {
        throw LevelsUnavailable('Not on the server or in the cache: $e');
      }
      if (docs.isEmpty) throw const LevelsUnavailable('Nothing cached yet');
    }
    return LevelCatalog(_parse(docs));
  }

  /// Worlds in order, stopping at the first one that doesn't parse or that
  /// repeats a level id of an earlier world, so a bad world can't shift the
  /// numbers of the levels after it or share progress with another board.
  static List<LevelWorld> _parse(List<LevelWorldDoc> docs) {
    final worlds = <LevelWorld>[];
    final seen = <String>{};
    for (final doc in docs) {
      final LevelWorld world;
      try {
        world = LevelWorld.fromJson(doc.id, doc.data);
      } on FormatException {
        break;
      }
      if (!world.levels.every((level) => seen.add(level.id))) break;
      worlds.add(world);
    }
    return worlds;
  }
}
