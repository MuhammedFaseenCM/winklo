import 'package:cloud_firestore/cloud_firestore.dart';

typedef LevelWorldDoc = ({String id, Map<String, dynamic> data});

/// Reads published `level_worlds` docs: Firestore in the app, a fake in
/// tests.
abstract class LevelWorldsSource {
  Future<List<LevelWorldDoc>> published(String game, {required bool fromCache});
}

class FirestoreLevelWorldsSource implements LevelWorldsSource {
  FirestoreLevelWorldsSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// The rules let players list only published worlds, so the query must
  /// filter on `published`. Needs the (game, published, order) index.
  @override
  Future<List<LevelWorldDoc>> published(
    String game, {
    required bool fromCache,
  }) async {
    final snap = await _firestore
        .collection('level_worlds')
        .where('game', isEqualTo: game)
        .where('published', isEqualTo: true)
        .orderBy('order')
        .get(GetOptions(source: fromCache ? Source.cache : Source.server));
    return [for (final d in snap.docs) (id: d.id, data: d.data())];
  }
}
