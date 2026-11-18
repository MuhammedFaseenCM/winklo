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
    this.daysCleared,
    this.stars,
    this.levelsCleared,
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

  /// Weekly board only: days of the week cleared. [timeSeconds] is then the
  /// week's total.
  final int? daysCleared;

  /// Levels board only: stars earned and levels cleared. [timeSeconds] is then
  /// the sum of the best times.
  final int? stars;
  final int? levelsCleared;

  /// This entry at another place on the board.
  LeaderboardEntry withRank(int rank) => LeaderboardEntry(
    uid: uid,
    displayName: displayName,
    photoUrl: photoUrl,
    avatarId: avatarId,
    timeSeconds: timeSeconds,
    updatedAt: updatedAt,
    rank: rank,
    usedHints: usedHints,
    hadMistakes: hadMistakes,
    currentStreak: currentStreak,
    daysCleared: daysCleared,
    stars: stars,
    levelsCleared: levelsCleared,
  );
}
