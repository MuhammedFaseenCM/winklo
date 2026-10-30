import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';

void main() {
  test('a first clear is not an improvement', () {
    const result = LevelClearResult(
      runStars: 2,
      current: LevelRecord(stars: 2, bestSeconds: 30),
    );
    expect(result.firstClear, isTrue);
    expect(result.moreStars, isFalse);
    expect(result.fasterTime, isFalse);
    expect(result.improved, isFalse);
  });

  test('more stars or a faster time improve the record', () {
    const stars = LevelClearResult(
      runStars: 3,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 3, bestSeconds: 30),
    );
    expect(stars.moreStars, isTrue);
    expect(stars.improved, isTrue);
    const time = LevelClearResult(
      runStars: 2,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 2, bestSeconds: 25),
    );
    expect(time.fasterTime, isTrue);
    expect(time.moreStars, isFalse);
    const same = LevelClearResult(
      runStars: 1,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 2, bestSeconds: 30),
    );
    expect(same.improved, isFalse);
  });

  test('a run both faster and with more stars is all three', () {
    const both = LevelClearResult(
      runStars: 3,
      previous: LevelRecord(stars: 2, bestSeconds: 30),
      current: LevelRecord(stars: 3, bestSeconds: 20),
    );
    expect(both.moreStars, isTrue);
    expect(both.fasterTime, isTrue);
    expect(both.improved, isTrue);
  });
}
