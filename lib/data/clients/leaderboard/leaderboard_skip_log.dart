/// Logs clears that never reached their board (`leaderboard_skips`), so the
/// admin can see who was left off, for which day, with what time and why.
abstract class LeaderboardSkipLog {
  /// Best effort: never throws, and skips the log when the player's daily
  /// entry already shows [skip]'s time or better (another device posted it,
  /// or an admin added it).
  Future<void> record(LeaderboardSkip skip);
}

/// One clear the leaderboard refused.
class LeaderboardSkip {
  const LeaderboardSkip({
    required this.uid,
    required this.gameId,
    required this.dayId,
    required this.timeSeconds,
    required this.reason,
    required this.usedHints,
    required this.hadMistakes,
    this.identity,
  });

  final String uid;
  final String gameId;

  /// The board's day, `yyyy-MM-dd`.
  final String dayId;

  final int timeSeconds;

  /// The `LeaderboardSubmitRefused` code.
  final String reason;

  final bool usedHints;
  final bool hadMistakes;

  /// As written on the boards; null when the profile couldn't be read.
  final ({String displayName, String? photoUrl, String? avatarId})? identity;
}
