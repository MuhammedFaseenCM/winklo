/// Stars a cleared level run earns, 1 to 3: one for clearing, one for using
/// no hints, one for a time at or under [targetSeconds].
///
/// [targetSeconds] null or 0 or less means the level has no time goal. A
/// run's [seconds] below 1 comes from a broken clock and can't earn the
/// time star.
int starsFor({
  required bool usedHints,
  required int seconds,
  required int? targetSeconds,
}) {
  final target = targetSeconds;
  final beatTarget =
      target != null && target > 0 && seconds >= 1 && seconds <= target;
  return 1 + (usedHints ? 0 : 1) + (beatTarget ? 1 : 0);
}
