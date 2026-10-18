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
    this.hintPenaltySeconds = 0,
    this.day,
    this.leaderboardProof,
    this.pathWords,
    this.local,
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

  /// Seconds the run's hints added to [timeSeconds] (already included).
  final int hintPenaltySeconds;

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

  /// Set for runs off the dailies (archive, practice, bonus games): Results
  /// then shows the time (or score) and the local best only, with no board,
  /// streak, share or achievements.
  final LocalResultInfo? local;
}

/// Which kind of run off the dailies a [LocalResultInfo] describes.
enum LocalResultKind { archive, practice, bonus }

/// What Results shows for a run off the dailies.
class LocalResultInfo {
  const LocalResultInfo({
    required this.kind,
    required this.label,
    this.bestSeconds,
    this.score,
    this.bestScore,
    this.scoreLabel,
    this.againLocation,
  });

  final LocalResultKind kind;

  /// "Archive · 9 Oct", "Practice", "Word Match · Opposites".
  final String label;

  /// The local best time after this run; null for score-only games.
  final int? bestSeconds;

  /// A score shown instead of the time (Category Race: words found).
  final int? score;

  /// The local best [score] after this run.
  final int? bestScore;

  /// What [score] counts ("words" when null).
  final String? scoreLabel;

  /// Where "New board" or "Play again" goes; null for none (the archive
  /// goes back to its calendar).
  final String? againLocation;
}
