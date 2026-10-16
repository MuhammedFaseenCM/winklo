import 'play_mode.dart';

/// What a hint costs on the run clock. Hints have no cap; instead the nth
/// hint of a run adds `n × [stepSeconds]` seconds, up to [maxSeconds] each
/// (+10s, +20s, … +60s), so a hinted clear can't outrank a clean one.
///
/// Dailies and the archive pay it; practice hints are free.
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

  /// Whether hints in [mode] cost time.
  static bool appliesTo(PlayMode mode) => !mode.isPractice;

  /// What the next hint costs in [mode] after [hintsUsed]: the hint
  /// button's "+20s".
  static int nextSeconds(PlayMode mode, {required int hintsUsed}) =>
      appliesTo(mode) ? secondsFor(hintsUsed + 1) : 0;
}
