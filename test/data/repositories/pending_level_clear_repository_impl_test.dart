import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/pending_level_clear_repository_impl.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/pending_level_clear.dart';

PendingLevelClear _clear(
  String levelId, {
  int stars = 2,
  int time = 40,
  bool hints = false,
}) => PendingLevelClear(
  levelId: levelId,
  stars: stars,
  timeSeconds: time,
  usedHints: hints,
  proof: const ZipLeaderboardProof([Cell(0, 0), Cell(0, 1)]),
);

void main() {
  late SharedPreferences prefs;
  late PendingLevelClearRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = PendingLevelClearRepositoryImpl(prefs);
  });

  test('betterThan: stars first, then time, equal is not better', () {
    expect(_clear('a', stars: 3).betterThan(_clear('a', stars: 2)), isTrue);
    expect(
      _clear('a', stars: 2, time: 10).betterThan(_clear('a', stars: 3)),
      isFalse,
    );
    expect(_clear('a', time: 30).betterThan(_clear('a', time: 40)), isTrue);
    expect(_clear('a', time: 40).betterThan(_clear('a', time: 40)), isFalse);
  });

  test('keeps the run with more stars even if slower', () async {
    await repo.keep('u', 'zip', _clear('l1', stars: 3, time: 40));
    await repo.keep('u', 'zip', _clear('l1', stars: 2, time: 10));

    final kept = repo.pending('u', 'zip').single;
    expect(kept.stars, 3);
    expect(kept.timeSeconds, 40);
  });

  test('on equal stars keeps the faster run', () async {
    await repo.keep('u', 'zip', _clear('l1', time: 40));
    await repo.keep('u', 'zip', _clear('l1', time: 30));
    expect(repo.pending('u', 'zip').single.timeSeconds, 30);

    await repo.keep('u', 'zip', _clear('l1', time: 35));
    expect(repo.pending('u', 'zip').single.timeSeconds, 30);
  });

  test('entries survive a new instance over the same prefs', () async {
    await repo.keep('u', 'zip', _clear('l1', hints: true));
    await repo.keep('u', 'zip', _clear('l2'));

    final again = PendingLevelClearRepositoryImpl(prefs).pending('u', 'zip');
    expect(again.map((c) => c.levelId), ['l1', 'l2']);
    expect(again.first.usedHints, isTrue);
    expect(again.first.proof.path, const [Cell(0, 0), Cell(0, 1)]);
  });

  test('is per account and per game', () async {
    await repo.keep('a', 'zip', _clear('l1'));

    expect(repo.pending('b', 'zip'), isEmpty);
    expect(repo.pending('a', 'sudoku'), isEmpty);
    expect(prefs.getKeys(), contains('pending_level_clears_a_zip'));
  });

  test('drop removes one level only', () async {
    await repo.keep('u', 'zip', _clear('l1'));
    await repo.keep('u', 'zip', _clear('l2'));

    await repo.drop('u', 'zip', 'l1');

    expect(repo.pending('u', 'zip').map((c) => c.levelId), ['l2']);
    await repo.drop('u', 'zip', 'l2');
    expect(prefs.getKeys(), isEmpty);
  });

  test('corrupt storage reads as empty', () async {
    await prefs.setString('pending_level_clears_u_zip', '{not json');
    expect(repo.pending('u', 'zip'), isEmpty);
  });
}
