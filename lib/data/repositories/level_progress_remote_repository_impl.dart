import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/level_progress.dart';
import '../../domain/repositories/level_progress_remote_repository.dart';

/// `users/{uid}/level_progress/{game}`: `{levels, updatedAt}`. The rules
/// accept only those two fields, with `updatedAt` the server's time.
class LevelProgressRemoteRepositoryImpl
    implements LevelProgressRemoteRepository {
  LevelProgressRemoteRepositoryImpl(
    this._firestore, {
    this.timeout = const Duration(seconds: 10),
  });

  final FirebaseFirestore _firestore;

  /// Offline writes only complete on server ack, so this often surfaces as a
  /// [TimeoutException]; the sync retries on its next run.
  final Duration timeout;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String game) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('level_progress')
          .doc(game);

  @override
  Future<Object?> fetch(String uid, String game) async {
    final snap = await _doc(
      uid,
      game,
    ).get(const GetOptions(source: Source.server)).timeout(timeout);
    return snap.data()?['levels'];
  }

  @override
  Future<void> save(String uid, String game, LevelProgress progress) =>
      _doc(uid, game)
          .set({
            'levels': progress.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(timeout);
}
