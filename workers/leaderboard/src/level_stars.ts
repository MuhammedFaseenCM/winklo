// Stars a cleared level run earns, 1 to 3: one for clearing, one for using no
// hints, one for a time at or under targetSeconds. Must match the app's
// starsFor (lib/domain/logic/level_stars.dart); fixtures/level_stars.json pins both.
//
// A null, 0 or negative target means the level has no time goal. Seconds below
// 1 comes from a broken clock and can't earn the time star.
export function starsFor(
  usedHints: boolean,
  seconds: number,
  targetSeconds: number | null | undefined,
): 1 | 2 | 3 {
  const beatTarget =
    targetSeconds != null && targetSeconds > 0 && seconds >= 1 && seconds <= targetSeconds;
  return (1 + (usedHints ? 0 : 1) + (beatTarget ? 1 : 0)) as 1 | 2 | 3;
}
