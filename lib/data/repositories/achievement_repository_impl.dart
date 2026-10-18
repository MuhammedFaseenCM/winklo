import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/achievement_repository.dart';

class AchievementRepositoryImpl implements AchievementRepository {
  AchievementRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  /// An `achievements_` key, so it is purged and stashed with the rest of
  /// the user's progress on an account switch (`userProgressKeyPrefixes`).
  static const seenKey = 'achievements_seen';

  @override
  Set<String> seenIds() => {...?_prefs.getStringList(seenKey)};

  @override
  Future<void> markSeen(Iterable<String> ids) async {
    final seen = seenIds();
    final next = {...seen, ...ids};
    if (next.length == seen.length) return;
    await _prefs.setStringList(seenKey, next.toList()..sort());
  }
}
