import 'achievement.dart';

/// The badge to chase next. Among the locked badges, the streak badge with
/// the most progress (current streak / target) wins; with no streak running,
/// the first locked badge in catalogue order (first clears come first).
/// Null when every badge is earned.
Achievement? nextAchievement(
  Set<String> unlocked, {
  Map<String, int> currentStreakByGame = const {},
}) {
  Achievement? best;
  var bestScore = -1.0;
  for (final a in Achievements.all) {
    if (unlocked.contains(a.id)) continue;
    final streak = a.kind == AchievementKind.streak
        ? currentStreakByGame[a.gameId] ?? 0
        : 0;
    final score = streak > 0 ? streak / a.target : 0.0;
    // Strictly greater: ties keep the earlier badge in the catalogue.
    if (score > bestScore) {
      best = a;
      bestScore = score;
    }
  }
  return best;
}
