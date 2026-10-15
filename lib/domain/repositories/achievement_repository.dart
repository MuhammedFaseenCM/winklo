/// Achievements already announced to the player (the Results banner shows
/// each new one once).
abstract class AchievementRepository {
  Set<String> seenIds();

  /// Adds [ids] to the seen set.
  Future<void> markSeen(Iterable<String> ids);
}
