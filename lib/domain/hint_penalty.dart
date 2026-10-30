import 'play_mode.dart';
import 'play_run_clock.dart';
import 'repositories/hint_quota_repository.dart';

/// What a hint costs on the run clock. Hints have no cap; instead the nth
/// hint of a run adds `n × [stepSeconds]` seconds, up to [maxSeconds] each
/// (+10s, +20s, … +60s), so a hinted clear can't outrank a clean one.
///
/// Dailies and the archive pay it; practice and level hints are free.
abstract final class HintPenalty {
  static const stepSeconds = 10;
  static const maxSeconds = 60;

  /// Seconds the [hintNumber]th hint of a run adds (1-based); 0 before the
  /// first.
  static int secondsFor(int hintNumber) {
    if (hintNumber <= 0) return 0;
    final seconds = hintNumber * stepSeconds;
    return seconds > maxSeconds ? maxSeconds : seconds;
  }

  /// Seconds the first [hintsUsed] hints of a run add together.
  static int totalSeconds(int hintsUsed) {
    var total = 0;
    for (var n = 1; n <= hintsUsed; n++) {
      total += secondsFor(n);
    }
    return total;
  }

  /// Whether hints in [mode] cost time. Practice hints are free; a level
  /// hint costs that level's no-hints star instead.
  static bool appliesTo(PlayMode mode) => !mode.isPractice && !mode.isLevel;

  /// What the next hint costs in [mode] after [hintsUsed]: the hint
  /// button's "+20s".
  static int nextSeconds(PlayMode mode, {required int hintsUsed}) =>
      appliesTo(mode) ? secondsFor(hintsUsed + 1) : 0;

  /// The time [hintsUsed] hints added to a run in [mode]: the results
  /// card's "Includes +30s from hints".
  static int chargedSeconds(PlayMode mode, {required int hintsUsed}) =>
      appliesTo(mode) ? totalSeconds(hintsUsed) : 0;

  /// The clock of a run starting fresh at [at] with [hintsUsed] already
  /// counted for its period (ops replaced the board, or the run began on
  /// another device): those hints' time carries over, so a new board or
  /// device can't wipe it.
  static PlayRunClock startClock({
    required DateTime at,
    required PlayMode mode,
    required int hintsUsed,
  }) => PlayRunClock.start(
    at: at,
  ).addPenalty(Duration(seconds: chargedSeconds(mode, hintsUsed: hintsUsed)));
}

/// A hint just spent: the run's hint count and the seconds this one costs.
typedef SpentHint = ({int hintsUsed, int penaltySeconds});

/// Spends a hint of a run in [mode] ([HintQuotaRepository.consume]) and
/// works out its cost. The caller adds that to its run clock after the
/// await, so a pause that lands meanwhile isn't lost.
Future<SpentHint> spendHint({
  required HintQuotaRepository quota,
  required PlayMode mode,
  required String gameId,
  required String playId,
}) async {
  final used = await quota.consume(gameId, playId);
  final seconds = HintPenalty.appliesTo(mode)
      ? HintPenalty.secondsFor(used)
      : 0;
  return (hintsUsed: used, penaltySeconds: seconds);
}
