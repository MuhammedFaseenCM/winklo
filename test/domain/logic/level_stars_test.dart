import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/logic/level_stars.dart';

void main() {
  int stars({bool hints = false, int seconds = 20, int? target = 30}) =>
      starsFor(usedHints: hints, seconds: seconds, targetSeconds: target);

  test('a clean run under the target earns all three', () {
    expect(stars(), 3);
  });

  test('exactly the target counts as beating it', () {
    expect(stars(seconds: 30), 3);
  });

  test('each missed goal costs one star', () {
    expect(stars(seconds: 31), 2);
    expect(stars(hints: true), 2);
    expect(stars(hints: true, seconds: 31), 1);
  });

  test('without a target there is no time star', () {
    expect(stars(target: null), 2);
    expect(stars(target: 0), 2);
    expect(stars(hints: true, target: null), 1);
  });

  test('a clear is never below one star, even with a broken clock', () {
    expect(stars(hints: true, seconds: 0), 1);
    expect(stars(seconds: 0), 2);
    expect(stars(seconds: -4), 2);
  });
}
