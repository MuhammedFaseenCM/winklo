import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/daily_puzzle_prefetch_repository_impl.dart';

void main() {
  test('reads the three daily puzzle docs for the day', () async {
    final reads = <String>[];
    final repo = DailyPuzzlePrefetchRepositoryImpl.withReader((path) async {
      reads.add(path);
    });

    expect(await repo.prefetch('20261016'), isTrue);

    expect(
      reads,
      unorderedEquals([
        'zip_levels/daily_20261016',
        'path_words_levels/daily_20261016',
        'sudoku_levels/daily_20261016',
      ]),
    );
  });

  test(
    'one refused read does not stop the others, and nothing throws',
    () async {
      final reads = <String>[];
      final repo = DailyPuzzlePrefetchRepositoryImpl.withReader((path) async {
        reads.add(path);
        if (path.startsWith('zip_levels/')) {
          throw Exception('[cloud_firestore/permission-denied]');
        }
      });

      await expectLater(repo.prefetch('20261016'), completion(isFalse));

      expect(reads, hasLength(3));
    },
  );

  test('without Firebase it reads nothing', () async {
    final repo = DailyPuzzlePrefetchRepositoryImpl();

    await expectLater(repo.prefetch('20261016'), completion(isFalse));
  });
}
