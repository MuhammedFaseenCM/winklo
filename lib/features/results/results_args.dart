import '../../domain/entities/leaderboard_period.dart';
import '../../domain/entities/leaderboard_proof.dart';
import '../../domain/entities/path_words_clear_summary.dart';

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
    this.day,
    this.leaderboardProof,
    this.pathWords,
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

  /// The daily this run cleared, for the share text.
  final DateTime? day;

  /// Lets the leaderboard Worker check the clear when a guest signs in to
  /// save it from Results.
  final LeaderboardProof? leaderboardProof;

  /// The board day of [day] (`yyyy-MM-dd`), or null for today's.
  String? get leaderboardDay {
    final cleared = day;
    return cleared == null ? null : leaderboardDayId(cleared);
  }

  /// Path Words only: the theme, found words and bonus words to show.
  final PathWordsClearSummary? pathWords;
}
