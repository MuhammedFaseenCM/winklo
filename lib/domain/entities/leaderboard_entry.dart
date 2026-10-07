class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.timeSeconds,
    required this.updatedAt,
    required this.rank,
    this.photoUrl,
    this.avatarId,
    this.usedHints,
    this.hadMistakes,
    this.currentStreak,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? avatarId;
  final int timeSeconds;
  final DateTime updatedAt;
  final int rank;

  /// When explicitly `false`, the daily board may show a "Hint-free" chip.
  /// Missing / null means unknown (legacy docs) — no chip.
  final bool? usedHints;

  /// When explicitly `false`, Sudoku daily board may show a "Flawless" chip.
  /// Missing / null means unknown (legacy docs) — no chip.
  final bool? hadMistakes;

  /// Current game streak at last sync. Daily board shows a chip when `>= 2`.
  /// Missing / null means unknown (legacy docs) — no chip.
  final int? currentStreak;
}
