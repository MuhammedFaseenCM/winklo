import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/core/firebase/firestore_read.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/features/zip/logic/daily_puzzle_generator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ZipLevelRepositoryImpl implements ZipLevelRepository {
  ZipLevelRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          (FirebaseBootstrap.isReady ? FirebaseFirestore.instance : null);

  final FirebaseFirestore? _firestore;

  @override
  Future<ZipLevel> fetchDailyLevel(
    DateTime date, {
    Duration period = PlayPeriod.daily,
  }) async {
    final id = DailyPuzzleGenerator.dateId(date, period: period);
    final firestore = _firestore;
    if (firestore == null) {
      throw const DailyPuzzleUnavailable('Firebase is not ready');
    }
    try {
      final doc = await getDocPreferringServer(
        firestore.collection('zip_levels').doc(id),
      );
      if (doc.exists && doc.data() != null) {
        return ZipLevel.fromJson(doc.data()!, id: doc.id);
      }
    } on DailyPuzzleUnavailable {
      rethrow;
    } catch (e) {
      throw DailyPuzzleUnavailable('Failed to load daily zip: $e');
    }
    throw DailyPuzzleUnavailable('Daily zip not found for $id');
  }
}
