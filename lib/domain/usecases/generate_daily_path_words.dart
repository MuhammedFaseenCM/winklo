import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/path_words/path_words_generator.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/word_list_repository.dart';

class GenerateDailyPathWords {
  GenerateDailyPathWords(
    this._words, {
    this.period = PlayPeriod.daily,
    FirebaseFirestore? firestore,
  }) : _firestore =
           firestore ??
           (FirebaseBootstrap.isReady ? FirebaseFirestore.instance : null);

  final WordListRepository _words;
  final Duration period;
  final FirebaseFirestore? _firestore;

  Future<PathWordsPuzzle> call({required DateTime day}) async {
    final local = day.toLocal();
    final bucket = PlayPeriod.bucket(local, period);
    final dateId = PlayPeriod.id(bucket, period);
    final id = 'daily_$dateId';

    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('path_words_levels')
            .doc(id)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 2));
        if (doc.exists && doc.data() != null) {
          return PathWordsPuzzle.fromJson(doc.data()!, id: doc.id);
        }
      } catch (_) {
        // fall through to local generator
      }
    }

    final list = await _words.loadDailyNouns(dateId: dateId);
    return PathWordsGenerator.generate(day: day, words: list, period: period);
  }
}
