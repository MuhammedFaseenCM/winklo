import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/path_words/path_words_generator.dart';
import 'package:winklo/domain/play_period.dart';
import 'package:winklo/domain/repositories/word_list_repository.dart';

class GenerateDailyPathWords {
  GenerateDailyPathWords(this._words, {this.period = PlayPeriod.daily});
  final WordListRepository _words;
  final Duration period;

  Future<PathWordsPuzzle> call({required DateTime day}) async {
    final local = day.toLocal();
    final bucket = PlayPeriod.bucket(local, period);
    final dateId = PlayPeriod.id(bucket, period);
    final list = await _words.loadDailyNouns(dateId: dateId);
    return PathWordsGenerator.generate(day: day, words: list, period: period);
  }
}
