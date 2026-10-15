import '../achievements/achievement.dart';
import '../achievements/achievement_rules.dart';
import '../repositories/achievement_repository.dart';
import 'load_game_history.dart';

/// Achievements earned since they were last announced (compared with the
/// stored seen set), in catalog order.
///
/// [pending] only reads; the caller calls [markShown] once they are on
/// screen, so a banner that never appeared (the player left first) leaves
/// them for the next one. An occasion (e.g. one Results screen) that was
/// already shown gets the same list back, so a remounted banner keeps it.
class ClaimNewAchievements {
  ClaimNewAchievements({required this._loadHistory, required this._store});

  final LoadGameHistory _loadHistory;
  final AchievementRepository _store;

  Object? _shownOccasion;
  List<Achievement> _shown = const [];

  Future<List<Achievement>> pending({Object? occasion}) async {
    if (occasion != null && identical(occasion, _shownOccasion)) return _shown;
    final history = await _loadHistory();
    final unlocked = unlockedAchievementIds(history.achievementInput);
    return newlyUnlocked(unlocked: unlocked, seen: _store.seenIds());
  }

  /// Marks [shown] as announced (for [occasion]).
  Future<void> markShown(List<Achievement> shown, {Object? occasion}) async {
    _shownOccasion = occasion;
    _shown = List.unmodifiable(shown);
    if (shown.isEmpty) return;
    await _store.markSeen([for (final a in shown) a.id]);
  }
}
