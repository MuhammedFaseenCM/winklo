import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/repositories/activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(this._prefs, {FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const _lastKey = 'activity_last_recorded_at_ms';

  final SharedPreferences _prefs;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  DateTime? lastRecordedAt() {
    final ms = _prefs.getInt(_lastKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> markRecorded(DateTime at) async {
    await _prefs.setInt(_lastKey, at.toUtc().millisecondsSinceEpoch);
  }

  @override
  Future<void> recordOpen({
    required String uid,
    required String dayId,
    required String platform,
    required DateTime at,
  }) async {
    final db = _db;
    if (db == null) return;
    final ref = db
        .collection('daily_activity')
        .doc(dayId)
        .collection('users')
        .doc(uid);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'uid': uid,
          'firstOpenAt': FieldValue.serverTimestamp(),
          'lastOpenAt': FieldValue.serverTimestamp(),
          'platform': platform,
        });
      } else {
        await ref.update({
          'lastOpenAt': FieldValue.serverTimestamp(),
          'platform': platform,
        });
      }
    } catch (e, st) {
      debugPrint('Activity recordOpen failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }
}
