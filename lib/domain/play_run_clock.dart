/// Pausable run clock: away time does not accumulate.
///
/// While running, [displayedMs] adds wall time since [resumedAt] to [elapsedMs].
/// [pause] folds that live delta into [elapsedMs] and clears [resumedAt].
class PlayRunClock {
  const PlayRunClock._({required this.elapsedMs, this.resumedAt});

  /// Frozen milliseconds counted so far (excludes time while paused).
  final int elapsedMs;

  /// When non-null, the clock is running from this instant.
  final DateTime? resumedAt;

  bool get isRunning => resumedAt != null;

  factory PlayRunClock.start({required DateTime at}) =>
      PlayRunClock._(elapsedMs: 0, resumedAt: at);

  /// Restores a saved paused clock (not running until [resume]).
  factory PlayRunClock.restore({required int elapsedMs}) =>
      PlayRunClock._(elapsedMs: elapsedMs < 0 ? 0 : elapsedMs);

  int displayedMs({required DateTime at}) {
    final resumed = resumedAt;
    if (resumed == null) return elapsedMs;
    final live = at.difference(resumed).inMilliseconds;
    return elapsedMs + (live < 0 ? 0 : live);
  }

  int displayedSeconds({required DateTime at}) => displayedMs(at: at) ~/ 1000;

  PlayRunClock pause({required DateTime at}) {
    if (!isRunning) return this;
    return PlayRunClock._(elapsedMs: displayedMs(at: at));
  }

  PlayRunClock resume({required DateTime at}) {
    if (isRunning) return this;
    return PlayRunClock._(elapsedMs: elapsedMs, resumedAt: at);
  }
}
