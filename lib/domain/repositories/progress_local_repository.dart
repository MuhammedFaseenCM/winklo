import '../entities/leaderboard_proof.dart';

/// Device-side bookkeeping for progress sync: who owns the local progress,
/// what was last pushed and the leaderboard proof of each daily clear.
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

  /// Drops what this device keeps of [uid] once that account is being
  /// deleted: the live progress when [uid] owns it (or nobody has claimed
  /// it yet), with the owner, plus [uid]'s stash and history-upload flag.
  /// Another account's live progress stays.
  Future<void> forgetUserProgress(String uid);

  /// Signature last pushed under [key] (one of the `*MarkerKey` values);
  /// null when never pushed.
  String? pushedSignature(String key);

  Future<void> setPushedSignature(String key, String signature);

  /// The leaderboard proof saved with [gameId]'s daily clear of [playId], so
  /// a later sync can send that clear through the leaderboard Worker; null
  /// when none was saved (clears before 1.1.0) or it can't be read.
  LeaderboardProof? clearProof(String gameId, String playId);

  Future<void> setClearProof(
    String gameId,
    String playId,
    LeaderboardProof proof,
  );

  /// Whether this device's daily history was uploaded once for [uid]
  /// (`UploadProgressHistory`). Kept per uid across purges.
  bool isHistoryUploaded(String uid);

  Future<void> setHistoryUploaded(String uid);
}
