import '../entities/leaderboard_entry.dart';
import '../entities/leaderboard_period.dart';
import '../entities/leaderboard_proof.dart';
import '../failures.dart';

/// The leaderboard refused a clear: the Worker checked it and refused it (a
/// time under the minimum, a day that isn't live, or a proof that doesn't
/// solve the puzzle), or the rules denied writing it directly
/// ([permissionDenied]: fair-play phase 2 turns direct writes off). Final:
/// sending the same clear again gets the same answer.
class LeaderboardSubmitRefused extends Failure {
  const LeaderboardSubmitRefused(this.code)
    : super('The leaderboard did not accept this time.', cause: code);

  /// The rules denied the direct write of a clear without a proof.
  static const permissionDenied = 'permission_denied';

  /// The Worker's error code, or [permissionDenied].
  final String code;
}

abstract class LeaderboardRepository {
  /// Live top entries for [gameId] and [period], ranked 1…n.
  /// For [LeaderboardPeriod.daily], [dayId] defaults to today's local calendar
  /// day; for [LeaderboardPeriod.weekly] the board is the ISO week holding it.
  /// Debug builds have no weekly board (only the Worker writes it): empty.
  Stream<List<LeaderboardEntry>> watchBoard({
    required String gameId,
    required LeaderboardPeriod period,
    String? dayId,
  });

  /// Live entries of [memberUids] (a league, 30 at most) on the same board as
  /// [watchBoard], ranked on the phone with the same rules.
  Stream<List<LeaderboardEntry>> watchMembersBoard({
    required String gameId,
    required LeaderboardPeriod period,
    required List<String> memberUids,
    String? dayId,
  });

  /// Improve-only write to all-time and a daily board for the signed-in user.
  ///
  /// [dayId] (`yyyy-MM-dd`) picks the daily board and defaults to today's
  /// local calendar day ([leaderboardDayId]).
  ///
  /// [currentStreak] is always merged when provided; time / clean-run flags
  /// update only when [timeSeconds] improves the stored best.
  ///
  /// When [expectedUid] is given the write is refused (throws) unless that
  /// account is still the signed-in one, so a run started for one account
  /// never lands on another account's entries after a switch.
  ///
  /// With a [proof], release builds post the clear to the leaderboard Worker,
  /// which checks it and writes the daily, all-time and weekly boards; if the
  /// Worker can't be reached they write the daily and all-time boards
  /// directly, as builds before 1.1.0 do. A refusal throws
  /// [LeaderboardSubmitRefused], and so does a direct write of a clear
  /// without a proof that the rules deny. A time under the game's minimum, or
  /// for a day whose board has closed, is skipped: no board would take it.
  Future<void> submitBestTime({
    required String gameId,
    required int timeSeconds,
    required bool usedHints,
    required bool hadMistakes,
    required int currentStreak,
    String? dayId,
    String? expectedUid,
    LeaderboardProof? proof,
  });
}
