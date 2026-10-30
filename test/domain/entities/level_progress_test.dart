import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/level_progress.dart';

void main() {
  const a = LevelProgress({
    'zip_1_01': LevelRecord(stars: 2, bestSeconds: 20),
    'zip_1_02': LevelRecord(stars: 1, bestSeconds: 50),
  });
  const b = LevelProgress({
    'zip_1_01': LevelRecord(stars: 3, bestSeconds: 25),
    'zip_1_03': LevelRecord(stars: 3, bestSeconds: 12),
  });

  test('merge keeps the most stars and the fastest time per level', () {
    final merged = a.merge(b);
    expect(merged['zip_1_01'], const LevelRecord(stars: 3, bestSeconds: 20));
    expect(merged['zip_1_02'], const LevelRecord(stars: 1, bestSeconds: 50));
    expect(merged['zip_1_03'], const LevelRecord(stars: 3, bestSeconds: 12));
  });

  test('merge is commutative and never makes a record worse', () {
    expect(a.merge(b).sameAs(b.merge(a)), isTrue);
    expect(a.merge(b).merge(a).sameAs(a.merge(b)), isTrue);
  });

  test('a run only ever improves its level', () {
    final slower = a.withRun('zip_1_01', stars: 1, seconds: 40);
    expect(slower['zip_1_01'], const LevelRecord(stars: 2, bestSeconds: 20));
    final better = a.withRun('zip_1_01', stars: 3, seconds: 18);
    expect(better['zip_1_01'], const LevelRecord(stars: 3, bestSeconds: 18));
    final first = a.withRun('zip_1_04', stars: 2, seconds: 0);
    expect(first['zip_1_04'], const LevelRecord(stars: 2, bestSeconds: 1));
  });

  test('stars add up and cleared levels are known', () {
    expect(a.totalStars, 3);
    expect(a.isCleared('zip_1_02'), isTrue);
    expect(a.isCleared('zip_1_03'), isFalse);
    expect(LevelProgress.empty.totalStars, 0);
  });

  test('parse drops invalid entries and counts them', () {
    final parsed = LevelProgress.parse({
      'zip_1_01': {'stars': 3, 'bestSeconds': 14},
      'zip_1_02': {'stars': 4, 'bestSeconds': 14},
      'zip_1_03': {'stars': 2, 'bestSeconds': 0},
      'zip_1_04': 'junk',
    });
    expect(parsed.dropped, 3);
    expect(parsed.progress.records.keys, ['zip_1_01']);
    expect(
      LevelProgress.parse(null).progress.sameAs(LevelProgress.empty),
      isTrue,
    );
    expect(LevelProgress.parse(null).dropped, 0);
  });

  test('toJson round-trips through parse', () {
    final again = LevelProgress.parse(a.toJson()).progress;
    expect(again.sameAs(a), isTrue);
  });
}
