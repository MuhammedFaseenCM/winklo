import 'package:winklo/domain/repositories/word_list_repository.dart';
import 'package:winklo/domain/usecases/generate_daily_path_words.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWords extends Mock implements WordListRepository {}

List<String> _fixtureWords() {
  final words = <String>[];
  for (var len = 3; len <= 5; len++) {
    for (var i = 0; i < 20; i++) {
      words.add('${'a' * (len - 1)}${String.fromCharCode(97 + (i % 26))}');
    }
  }
  return words;
}

void main() {
  late _MockWords repo;
  late GenerateDailyPathWords usecase;
  late List<String> fixtureWords;

  setUp(() {
    repo = _MockWords();
    usecase = GenerateDailyPathWords(repo);
    fixtureWords = _fixtureWords();
  });

  test('loads daily nouns and generates puzzle', () async {
    when(
      () => repo.loadDailyNouns(dateId: '20260917'),
    ).thenAnswer((_) async => fixtureWords);

    final puzzle = await usecase(day: DateTime(2026, 9, 17));

    expect(puzzle.id, 'path_words_20260917');
    expect(puzzle.size, inInclusiveRange(3, 6));
    expect(puzzle.targets.length, inInclusiveRange(3, 6));
    verify(() => repo.loadDailyNouns(dateId: '20260917')).called(1);
  });
}
