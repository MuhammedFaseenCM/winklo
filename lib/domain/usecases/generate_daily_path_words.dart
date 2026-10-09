import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/core/firebase/firestore_read.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/play_period.dart';

class GenerateDailyPathWords {
  GenerateDailyPathWords({
    this.period = PlayPeriod.daily,
    FirebaseFirestore? firestore,
  }) : _firestore =
           firestore ??
           (FirebaseBootstrap.isReady ? FirebaseFirestore.instance : null);

  final Duration period;
  final FirebaseFirestore? _firestore;

  Future<PathWordsPuzzle> call({required DateTime day}) async {
    final local = day.toLocal();
    final bucket = PlayPeriod.bucket(local, period);
    final dateId = PlayPeriod.id(bucket, period);
    final id = 'daily_$dateId';

    final firestore = _firestore;
    if (firestore == null) {
      throw const DailyPuzzleUnavailable('Firebase is not ready');
    }

    try {
      final doc = await getDocPreferringServer(
        firestore.collection('path_words_levels').doc(id),
      );
      if (doc.exists && doc.data() != null) {
        return PathWordsPuzzle.fromJson(doc.data()!, id: doc.id);
      }
    } on DailyPuzzleUnavailable {
      rethrow;
    } catch (e) {
      throw DailyPuzzleUnavailable('Failed to load daily path words: $e');
    }

    throw DailyPuzzleUnavailable('Daily path words not found for $dateId');
  }
}
