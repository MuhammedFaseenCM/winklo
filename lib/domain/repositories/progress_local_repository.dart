/// Device-side bookkeeping for progress sync: who owns the local progress and
/// what was last pushed.
abstract class ProgressLocalRepository {
  /// Marker key for the pushed `game_days` doc of [gameId] / [playId].
  static String dayMarkerKey(String gameId, String playId) =>
      'day_${gameId}_$playId';

  /// Marker key for the leaderboard time confirmed for [gameId] / [playId].
  static String leaderboardMarkerKey(String gameId, String playId) =>
      'lb_${gameId}_$playId';

  /// Marker key for the pushed `game_streaks` doc of [gameId].
  static String streakMarkerKey(String gameId) => 'streak_$gameId';

  /// Uid that owns the local progress; null for legacy (unclaimed) data.
  String? get ownerUid;

  Future<void> setOwnerUid(String uid);

  /// Removes all per-user progress (scores, clear meta, streaks, hint quota,
  /// drafts, sync markers).
  Future<void> purgeUserProgress();

  /// Copies all per-user progress aside under [uid] (replacing an earlier
  /// stash for that uid) so an account switch does not lose progress that was
  /// never pushed. Live keys are left alone; [purgeUserProgress] removes them.
  Future<void> stashUserProgress(String uid);

  /// Moves [uid]'s stash back into the live keys and deletes it. Returns
  /// whether anything was restored.
  Future<bool> restoreStashedProgress(String uid);

  /// Signature last pushed under [key] (one of the `*MarkerKey` values);
  /// null when never pushed.
  String? pushedSignature(String key);

  Future<void> setPushedSignature(String key, String signature);
}
