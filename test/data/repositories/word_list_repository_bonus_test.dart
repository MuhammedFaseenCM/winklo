import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/word_list_repository_impl.dart';

/// Counts reads of the bonus list, and serves everything else from the app bundle.
class _CountingBundle extends CachingAssetBundle {
  final reads = <String>[];

  @override
  Future<ByteData> load(String key) {
    reads.add(key);
    return rootBundle.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    reads.add(key);
    return rootBundle.loadString(key, cache: false);
  }
}

class _FailingOnceBundle extends CachingAssetBundle {
  var calls = 0;

  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    calls++;
    if (calls == 1) return Future.error(StateError('disk'));
    return rootBundle.loadString(key, cache: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the bonus list is 4–8 lowercase letters with real words in it',
    () async {
      final words = await WordListRepositoryImpl().loadBonusWords();
      expect(words.length, greaterThan(50000));
      expect(words.every((w) => RegExp(r'^[a-z]{4,8}$').hasMatch(w)), isTrue);
      for (final word in ['stare', 'cedar', 'quiver', 'kitchen', 'niggle']) {
        expect(words, contains(word));
      }
    },
  );

  test('the bonus list leaves out slurs and profanity', () async {
    final words = await WordListRepositoryImpl().loadBonusWords();
    for (final word in ['fuck', 'shit', 'cunt', 'bitch', 'whore', 'nigger']) {
      expect(words, isNot(contains(word)));
    }
  });

  test('loads lazily, once, and shares one read between callers', () async {
    final bundle = _CountingBundle();
    final repo = WordListRepositoryImpl(bundle: bundle);
    expect(bundle.reads, isEmpty);
    final results = await Future.wait([
      repo.loadBonusWords(),
      repo.loadBonusWords(),
    ]);
    expect(identical(results[0], results[1]), isTrue);
    expect(identical(await repo.loadBonusWords(), results[0]), isTrue);
    expect(bundle.reads, ['assets/words/en_bonus_words.txt']);
  });

  test('a failed read is retried on the next call', () async {
    final bundle = _FailingOnceBundle();
    final repo = WordListRepositoryImpl(bundle: bundle);
    await expectLater(repo.loadBonusWords(), throwsStateError);
    expect(await repo.loadBonusWords(), contains('stare'));
  });
}
