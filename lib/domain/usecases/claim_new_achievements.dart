import '../achievements/achievement.dart';
import '../achievements/achievement_rules.dart';
import '../repositories/achievement_repository.dart';
import 'load_game_history.dart';

/// Achievements earned since the last call (compared with the stored seen
/// set), in catalog order; they are marked seen, so each is returned once.
class ClaimNewAchievements {
  ClaimNewAchievements({required this._loadHistory, required this._store});

  final LoadGameHistory _loadHistory;
  final AchievementRepository _store;

  Future<List<Achievement>> call() async {
    final history = await _loadHistory();
    final unlocked = unlockedAchievementIds(history.achievementInput);
    final fresh = newlyUnlocked(unlocked: unlocked, seen: _store.seenIds());
    if (fresh.isNotEmpty) await _store.markSeen(unlocked);
    return fresh;
  }
}
