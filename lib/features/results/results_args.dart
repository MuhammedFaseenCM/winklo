class ResultsArgs {
  const ResultsArgs({
    required this.title,
    required this.subtitle,
    required this.timeSeconds,
    required this.improved,
    this.points,
    this.replayDaily = false,
    this.replayRoute,
    this.replayLevelId,
    this.nextLevelId,
    this.currentStreak,
    this.longestStreak,
    this.gameId,
    this.usedHints,
    this.hadMistakes,
  });

  final String title;
  final String subtitle;
  final int timeSeconds;
  final bool improved;
  final int? points;
  final bool replayDaily;
  final String? replayRoute;
  final String? replayLevelId;
  final String? nextLevelId;
  final int? currentStreak;
  final int? longestStreak;
  final String? gameId;

  /// Session flags for soft-claim leaderboard sync. Null = unknown.
  final bool? usedHints;
  final bool? hadMistakes;
}
