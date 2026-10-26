import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/habit/shuffle_bag.dart';

void main() {
  List<int> run(String key, int size, {int from = 20380, int? count}) => [
    for (var turn = from; turn < from + (count ?? 2 * size + 2); turn++)
      ShuffleBag.pick(key, turn, size),
  ];

  // The same vectors as winklo-admin's workers/admin-api/src/shuffle_bag.ts:
  // both sides must pick the same line for the same key and turn.
  test('matches the Worker’s vectors', () {
    expect(run('morning', 7), [0, 1, 5, 2, 6, 2, 0, 3, 5, 4, 1, 6, 5, 4, 2, 1]);
    expect(run('streak', 5), [2, 1, 3, 0, 4, 2, 4, 3, 0, 1, 0, 2]);
    expect(run('uid42|zip', 12), [
      8, 6, 2, 9, 7, 11, 4, 5, 0, 5, 2, 11, 6, 8, 7, 3, 4, 10, 1, 9, //
      8, 9, 3, 6, 10, 1,
    ]);
    expect(run('x', 2), [1, 0, 1, 0, 1, 0]);
  });

  test('fnv1a and mulberry32 match the Worker', () {
    expect(ShuffleBag.fnv1a('morning#0'), 4087581884);
    expect(
      ShuffleBag.mulberry32(4087581884)(),
      closeTo(0.6416847859509289, 1e-15),
    );
  });

  test('a pool of one or none always gives 0', () {
    expect(ShuffleBag.pick('a', 5, 1), 0);
    expect(ShuffleBag.pick('a', 5, 0), 0);
  });

  const keys = ['morning', 'lapsed', 'streak3', 'a', 'uid|zip'];

  test('each pass uses every line once', () {
    for (final size in [3, 4, 5, 7, 12, 30]) {
      for (final key in keys) {
        for (var pass = 0; pass < 30; pass++) {
          final seen = {
            for (var i = 0; i < size; i++)
              ShuffleBag.pick(key, pass * size + i, size),
          };
          expect(seen.length, size, reason: '$key size $size pass $pass');
        }
      }
    }
  });

  test('never the same line two turns running', () {
    for (final size in [2, 3, 4, 5, 7, 12, 30]) {
      for (final key in keys) {
        var previous = -1;
        for (var turn = 0; turn < size * 30; turn++) {
          final line = ShuffleBag.pick(key, turn, size);
          expect(line, isNot(previous), reason: '$key size $size turn $turn');
          previous = line;
        }
      }
    }
  });

  test('epochDay counts local calendar days', () {
    expect(ShuffleBag.epochDay(DateTime(1970, 1, 1, 23, 59)), 0);
    expect(ShuffleBag.epochDay(DateTime(2026, 10, 26, 0, 1)), 20752);
    expect(ShuffleBag.epochDay(DateTime(2026, 10, 26, 23, 59)), 20752);
    expect(ShuffleBag.epochDay(DateTime(2026, 10, 27, 8)), 20753);
  });
}
