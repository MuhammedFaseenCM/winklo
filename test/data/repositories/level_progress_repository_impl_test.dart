import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/entities/level_progress.dart';

void main() {
  late SharedPreferences prefs;
  late String? uid;
  late int syncAsks;
  late LevelProgressRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    uid = 'u1';
    syncAsks = 0;
    repo = LevelProgressRepositoryImpl(
      prefs,
      currentUid: () => uid,
      onChanged: () => syncAsks++,
    );
  });

  tearDown(() => repo.dispose());

  test('a first clear is recorded and asks for a sync', () async {
    final result = await repo.record('zip', 'zip_1_01', stars: 2, seconds: 30);
    expect(result.firstClear, isTrue);
    expect(result.runStars, 2);
    expect(
      repo.progress('zip')['zip_1_01'],
      const LevelRecord(stars: 2, bestSeconds: 30),
    );
    expect(syncAsks, 1);
  });

  test('a replay keeps the best of both', () async {
    await repo.record('zip', 'zip_1_01', stars: 2, seconds: 30);
    final worse = await repo.record('zip', 'zip_1_01', stars: 1, seconds: 45);
    expect(worse.improved, isFalse);
    expect(worse.current, const LevelRecord(stars: 2, bestSeconds: 30));
    final better = await repo.record('zip', 'zip_1_01', stars: 3, seconds: 20);
    expect(better.moreStars, isTrue);
    expect(better.previous, const LevelRecord(stars: 2, bestSeconds: 30));
  });

  test('each account has its own map', () async {
    await repo.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    uid = 'u2';
    expect(repo.progress('zip').records, isEmpty);
    uid = 'u1';
    expect(repo.progress('zip').totalStars, 3);
  });

  test('restore fires changes but does not ask for a sync', () async {
    final changes = <void>[];
    final sub = repo.changes.listen(changes.add);
    await repo.restore(
      'zip',
      const LevelProgress({'zip_1_02': LevelRecord(stars: 1, bestSeconds: 9)}),
    );
    await pumpEventQueue();
    expect(changes, hasLength(1));
    expect(syncAsks, 0);
    expect(repo.progress('zip').isCleared('zip_1_02'), isTrue);
    await sub.cancel();
  });

  test('needsPush until what is stored has been pushed', () async {
    expect(repo.needsPush('zip'), isFalse);
    await repo.record('zip', 'zip_1_01', stars: 2, seconds: 30);
    expect(repo.needsPush('zip'), isTrue);
    await repo.markPushed('zip', repo.progress('zip'));
    expect(repo.needsPush('zip'), isFalse);
  });

  test('a corrupt stored value reads as empty progress', () async {
    await prefs.setString('level_progress_u1_zip', '{not json');
    expect(repo.progress('zip').records, isEmpty);
  });
}
