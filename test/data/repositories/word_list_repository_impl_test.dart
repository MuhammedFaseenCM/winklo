import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/clients/path_words/path_words_nouns_client.dart';
import 'package:winklo/data/repositories/word_list_repository_impl.dart';

class _MockNounsClient extends Mock implements PathWordsNounsClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNounsClient nounsClient;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nounsClient = _MockNounsClient();
  });

  test('loads and filters 4–10 letter words', () async {
    final repo = WordListRepositoryImpl();
    final words = await repo.loadEnglishWords();
    expect(words, isNotEmpty);
    expect(words.every((w) => w.length >= 4 && w.length <= 10), isTrue);
    expect(words.every((w) => w == w.toLowerCase()), isTrue);
  });

  test('loadDailyNouns returns network words and caches them', () async {
    when(
      () => nounsClient.fetchNouns(dateId: '20260925'),
    ).thenAnswer((_) async => ['cat', 'tree', 'ocean']);

    final repo = WordListRepositoryImpl(
      prefs: prefs,
      nounsClient: nounsClient,
      nounAssetPath: 'assets/words/en_nouns.txt',
    );

    final words = await repo.loadDailyNouns(dateId: '20260925');
    expect(words, ['cat', 'ocean', 'tree']); // normalized + sorted
    expect(prefs.getString('path_words_nouns_20260925'), isNotNull);
    verify(() => nounsClient.fetchNouns(dateId: '20260925')).called(1);
  });

  test('loadDailyNouns prefers prefs cache over network', () async {
    await prefs.setString(
      'path_words_nouns_20260925',
      jsonEncode(['dog', 'bird', 'lake']),
    );

    final repo = WordListRepositoryImpl(
      prefs: prefs,
      nounsClient: nounsClient,
      nounAssetPath: 'assets/words/en_nouns.txt',
    );

    final words = await repo.loadDailyNouns(dateId: '20260925');
    expect(words, ['bird', 'dog', 'lake']); // normalized + sorted
    verifyNever(() => nounsClient.fetchNouns(dateId: any(named: 'dateId')));
  });

  test(
    'loadDailyNouns falls back to bundled nouns when network fails',
    () async {
      when(
        () => nounsClient.fetchNouns(dateId: '20260925'),
      ).thenThrow(StateError('offline'));

      final repo = WordListRepositoryImpl(
        prefs: prefs,
        nounsClient: nounsClient,
        nounAssetPath: 'assets/words/en_nouns.txt',
      );

      final words = await repo.loadDailyNouns(dateId: '20260925');
      expect(words, isNotEmpty);
      expect(words.every((w) => w.length >= 3 && w.length <= 5), isTrue);
      expect(words.every((w) => RegExp(r'^[a-z]+$').hasMatch(w)), isTrue);
    },
  );
}
