import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/level_play_stats_repository.dart';

/// `users/{uid}/level_stats/{game}`: one merge write per event, an increment
/// on the level's counter plus server timestamps. Increments add up across
/// devices; a write made offline waits in Firestore's queue, so this is not
/// given a timeout (the caller never awaits it on the UI path).
class LevelPlayStatsRepositoryImpl implements LevelPlayStatsRepository {
  LevelPlayStatsRepositoryImpl([this._firestore]);

  /// Null reads [FirebaseFirestore.instance] on first use.
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> increment(
    String uid,
    String game,
    String levelId,
    LevelPlayEvent event,
  ) => _db
      .collection('users')
      .doc(uid)
      .collection('level_stats')
      .doc(game)
      .set({
        'levels': {
          levelId: {
            event.field: FieldValue.increment(1),
            'lastPlayedAt': FieldValue.serverTimestamp(),
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
