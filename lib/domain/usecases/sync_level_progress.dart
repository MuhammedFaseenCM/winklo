import '../entities/level_progress.dart';
import '../game_ids.dart';
import '../repositories/auth_repository.dart';
import '../repositories/level_progress_remote_repository.dart';
import '../repositories/level_progress_repository.dart';

/// Reconciles this device's level progress with the account's copy.
///
/// Per game: read the remote doc, merge (most stars, fastest time), keep the
/// result locally, and write it back only when the remote copy differs. A
/// push-only run ([pull] false) skips games with nothing new to push. The
/// merge can't conflict, so the order of devices never matters.
class SyncLevelProgress {
  SyncLevelProgress({
    required AuthRepository auth,
    required LevelProgressRepository local,
    required LevelProgressRemoteRepository remote,
    bool Function()? isRemoteAvailable,
  }) : _auth = auth,
       _local = local,
       _remote = remote,
       _isRemoteAvailable = isRemoteAvailable ?? _always;

  /// Games with Levels.
  static const gameIds = [GameIds.zip];

  final AuthRepository _auth;
  final LevelProgressRepository _local;
  final LevelProgressRemoteRepository _remote;
  final bool Function() _isRemoteAvailable;

  static bool _always() => true;

  Future<void> call({required bool pull}) async {
    if (!_isRemoteAvailable()) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    for (final game in gameIds) {
      if (!pull && !_local.needsPush(game)) continue;
      final remote = LevelProgress.parse(await _remote.fetch(uid, game));
      // Another account signed in while we read: leave both copies alone.
      if (_auth.currentUser?.uid != uid) return;
      final local = _local.progress(game);
      final merged = local.merge(remote.progress);
      if (!merged.sameAs(local)) await _local.restore(game, merged);
      if (!merged.sameAs(remote.progress) || remote.dropped > 0) {
        await _remote.save(uid, game, merged);
      }
      // The local store is keyed by whoever is signed in now.
      if (_auth.currentUser?.uid != uid) return;
      await _local.markPushed(game, merged);
    }
  }
}
