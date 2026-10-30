import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/clients/level_worlds_source.dart';
import 'package:winklo/data/repositories/level_world_repository_impl.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';

import '../../helpers/level_fixtures.dart';

class _FakeSource implements LevelWorldsSource {
  List<LevelWorldDoc>? server;
  List<LevelWorldDoc>? cache;
  final calls = <bool>[];
  Future<List<LevelWorldDoc>> Function()? serverOverride;

  @override
  Future<List<LevelWorldDoc>> published(
    String game, {
    required bool fromCache,
  }) async {
    calls.add(fromCache);
    if (!fromCache && serverOverride != null) return serverOverride!();
    final docs = fromCache ? cache : server;
    if (docs == null) throw StateError(fromCache ? 'no cache' : 'offline');
    return docs;
  }
}

LevelWorldDoc doc(int order, int count) =>
    (id: 'zip_$order', data: levelWorldJson(order, count));

void main() {
  late _FakeSource source;

  setUp(() => source = _FakeSource());

  test('reads the server first', () async {
    source.server = [doc(1, 3), doc(2, 2)];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.levelCount, 5);
    expect(source.calls, [false]);
  });

  test('falls back to the cache when the server fails', () async {
    source.cache = [doc(1, 3)];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.levelCount, 3);
    expect(source.calls, [false, true]);
  });

  test('is unavailable when neither has levels', () async {
    final repo = LevelWorldRepositoryImpl(source);
    await expectLater(repo.catalog('zip'), throwsA(isA<LevelsUnavailable>()));
    source.cache = [];
    await expectLater(repo.catalog('zip'), throwsA(isA<LevelsUnavailable>()));
    await expectLater(
      LevelWorldRepositoryImpl(null).catalog('zip'),
      throwsA(isA<LevelsUnavailable>()),
    );
  });

  test('no published worlds on the server is an empty catalog', () async {
    source.server = [];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.isEmpty, isTrue);
  });

  test('stops at the first world that does not parse', () async {
    source.server = [
      doc(1, 2),
      (id: 'zip_2', data: <String, dynamic>{'order': 2}),
      doc(3, 2),
    ];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.worlds.map((w) => w.id), ['zip_1']);
  });

  test('stops at a world that repeats an earlier level id', () async {
    final repeat = levelWorldJson(2, 1)
      ..['levels'] = [levelBoardJson('zip_1_02')];
    source.server = [doc(1, 2), (id: 'zip_2', data: repeat), doc(3, 2)];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.worlds.map((w) => w.id), ['zip_1']);
  });

  test('keeps the catalog for the session; refresh reads again', () async {
    source.server = [doc(1, 2)];
    final repo = LevelWorldRepositoryImpl(source);
    await repo.catalog('zip');
    await repo.catalog('zip');
    expect(source.calls, [false]);
    await repo.catalog('zip', refresh: true);
    expect(source.calls, [false, false]);
  });

  test('a failure is not kept: the next call tries again', () async {
    final repo = LevelWorldRepositoryImpl(source);
    await expectLater(repo.catalog('zip'), throwsA(isA<LevelsUnavailable>()));
    source.server = [doc(1, 2)];
    final catalog = await repo.catalog('zip');
    expect(catalog.levelCount, 2);
  });

  test('gives up on a slow server and uses the cache', () async {
    source
      ..serverOverride = (() => Completer<List<LevelWorldDoc>>().future)
      ..cache = [doc(1, 3)];
    final repo = LevelWorldRepositoryImpl(
      source,
      serverTimeout: const Duration(milliseconds: 10),
    );
    final catalog = await repo.catalog('zip');
    expect(catalog.levelCount, 3);
    expect(source.calls, [false, true]);
  });

  test(
    'a cached fallback is not kept: the next call tries the server',
    () async {
      source.cache = [doc(1, 2)];
      final repo = LevelWorldRepositoryImpl(source);
      expect((await repo.catalog('zip')).worlds, hasLength(1));
      source.server = [doc(1, 2), doc(2, 2)];
      expect((await repo.catalog('zip')).worlds, hasLength(2));
      expect(source.calls, [false, true, false]);
    },
  );

  test('concurrent calls share one server read', () async {
    source.server = [doc(1, 2)];
    final repo = LevelWorldRepositoryImpl(source);
    await Future.wait([repo.catalog('zip'), repo.catalog('zip')]);
    expect(source.calls, [false]);
  });

  test('a stale failing load does not evict a newer refreshed one', () async {
    final slow = Completer<List<LevelWorldDoc>>();
    source.serverOverride = () => slow.future;
    final repo = LevelWorldRepositoryImpl(source);
    final first = repo.catalog('zip');
    final firstResult = expectLater(first, throwsA(isA<LevelsUnavailable>()));

    source.serverOverride = null;
    source.server = [doc(1, 2)];
    await repo.catalog('zip', refresh: true);

    slow.completeError(StateError('late'));
    await firstResult;

    await repo.catalog('zip');
    expect(source.calls, [false, false, true]);
  });

  test('a cache with only unparseable docs is an empty catalog', () async {
    source.cache = [
      (id: 'zip_1', data: <String, dynamic>{'order': 1}),
    ];
    final catalog = await LevelWorldRepositoryImpl(source).catalog('zip');
    expect(catalog.isEmpty, isTrue);
  });
}
