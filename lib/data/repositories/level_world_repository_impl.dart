import 'package:flutter/foundation.dart';

import '../../core/firebase/firestore_read.dart';
import '../../domain/entities/level_world.dart';
import '../../domain/logic/level_catalog.dart';
import '../../domain/play_mode.dart';
import '../../domain/repositories/level_world_repository.dart';
import '../clients/level_worlds_source.dart';

class LevelWorldRepositoryImpl implements LevelWorldRepository {
  /// [source] is null while Firebase isn't ready.
  LevelWorldRepositoryImpl(
    this._source, {
    this.serverTimeout = dailyPuzzleServerTimeout,
  });

  final LevelWorldsSource? _source;
  final Duration serverTimeout;
  final Map<String, Future<LevelCatalog>> _loaded = {};

  /// Kept for the session once read from the server; a cached fallback is not
  /// kept, so the next call tries the server again.
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) {
    if (refresh) _loaded.remove(game);
    final kept = _loaded[game];
    if (kept != null) return kept;
    late final Future<LevelCatalog> future;
    Future<LevelCatalog> run() async {
      try {
        final loaded = await _load(game);
        if (!loaded.fromServer) _forget(game, future);
        return loaded.catalog;
      } catch (_) {
        // Forget failures so the next call retries.
        _forget(game, future);
        rethrow;
      }
    }

    future = run();
    _loaded[game] = future;
    return future;
  }

  void _forget(String game, Future<LevelCatalog> future) {
    if (identical(_loaded[game], future)) _loaded.remove(game);
  }

  Future<({LevelCatalog catalog, bool fromServer})> _load(String game) async {
    final source = _source;
    if (source == null) throw const LevelsUnavailable('Firebase is not ready');
    List<LevelWorldDoc> docs;
    var fromServer = true;
    try {
      // The SDK only gives up on the server once it decides it's offline,
      // which can take longer than a player will wait.
      docs = await source
          .published(game, fromCache: false)
          .timeout(serverTimeout);
    } catch (e) {
      debugPrint('Level worlds: server read failed, using the cache: $e');
      fromServer = false;
      try {
        docs = await source.published(game, fromCache: true);
      } catch (e) {
        throw LevelsUnavailable('Not on the server or in the cache: $e');
      }
      if (docs.isEmpty) throw const LevelsUnavailable('Nothing cached yet');
    }
    return (catalog: LevelCatalog(_parse(docs, game)), fromServer: fromServer);
  }

  /// Worlds in order, stopping at the first one that doesn't parse, that
  /// repeats a level id of an earlier world, or that has a level id a route
  /// can't carry or that names another game (`{game}_…`), so a bad world
  /// can't shift the numbers of the levels after it or share progress with
  /// another board.
  static List<LevelWorld> _parse(List<LevelWorldDoc> docs, String game) {
    final worlds = <LevelWorld>[];
    final seen = <String>{};
    for (final doc in docs) {
      final LevelWorld world;
      try {
        world = LevelWorld.fromJson(doc.id, doc.data);
      } on FormatException {
        break;
      }
      final prefix = '${world.game.isEmpty ? game : world.game}_';
      final idsOk = world.levels.every(
        (level) =>
            PlayMode.levelIdPattern.hasMatch(level.id) &&
            level.id.startsWith(prefix),
      );
      if (!idsOk) break;
      if (!world.levels.every((level) => seen.add(level.id))) break;
      worlds.add(world);
    }
    return worlds;
  }
}
