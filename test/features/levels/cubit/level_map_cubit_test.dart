import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/usecases/submit_level_clear.dart';
import 'package:winklo/features/levels/cubit/level_map_cubit.dart';

import '../../../helpers/level_fixtures.dart';

class _Worlds implements LevelWorldRepository {
  LevelCatalog? value;
  int calls = 0;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async {
    calls++;
    final v = value;
    if (v == null) throw const LevelsUnavailable('offline');
    return v;
  }
}

class _MockLeaderboard extends Mock implements LeaderboardRepository {}

class _MockSubmitLevelClear extends Mock implements SubmitLevelClear {}

void main() {
  late _Worlds worlds;
  late LevelProgressRepositoryImpl progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    worlds = _Worlds();
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
  });

  LevelMapCubit build() => LevelMapCubit(worlds: worlds, progress: progress);

  test('loads the map', () async {
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.ready);
    expect(cubit.state.map!.currentId, 'zip_1_01');
    await cubit.close();
  });

  test('offline with nothing cached is unavailable; retry recovers', () async {
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.unavailable);
    worlds.value = LevelCatalog([levelWorld(1, 1)]);
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.ready);
    await cubit.close();
  });

  test('no published worlds is empty', () async {
    worlds.value = LevelCatalog(const []);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.empty);
    await cubit.close();
  });

  test('a new clear rebuilds the map without reloading worlds', () async {
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = build();
    await cubit.load();
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pumpEventQueue();
    expect(cubit.state.map!.currentId, 'zip_1_02');
    expect(cubit.state.map!.stars, 3);
    expect(worlds.calls, 1);
    await cubit.close();
  });

  test('an account switch shows the new account\'s progress', () async {
    var uid = 'u1';
    final owner = StreamController<String?>();
    final repo = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => uid,
      ownerChanges: owner.stream,
    );
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = LevelMapCubit(worlds: worlds, progress: repo);
    await cubit.load();
    await repo.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pumpEventQueue();
    expect(cubit.state.map!.currentId, 'zip_1_02');
    uid = 'u2';
    owner.add('u2');
    await pumpEventQueue();
    expect(cubit.state.map!.currentId, 'zip_1_01');
    expect(cubit.state.map!.stars, 0);
    await cubit.close();
    await repo.dispose();
    await owner.close();
  });

  test('keeps a loaded map when a later load fails', () async {
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = build();
    await cubit.load();
    worlds.value = null;
    await cubit.load();
    expect(cubit.state.status, LevelMapStatus.ready);
    expect(worlds.calls, 2);
    await cubit.close();
  });

  test('a progress change after close does not throw', () async {
    worlds.value = LevelCatalog([levelWorld(1, 2)]);
    final cubit = build();
    await cubit.load();
    await cubit.close();
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pumpEventQueue();
  });

  group('board level ids', () {
    late _MockLeaderboard leaderboard;

    setUp(() {
      leaderboard = _MockLeaderboard();
      worlds.value = LevelCatalog([levelWorld(1, 2)]);
    });

    LevelMapCubit withBoard() => LevelMapCubit(
      worlds: worlds,
      progress: progress,
      leaderboard: leaderboard,
    );

    test('loads once per load', () async {
      when(
        () => leaderboard.myBoardLevelIds('zip'),
      ).thenAnswer((_) async => {'zip_1_01'});
      final cubit = withBoard();
      await cubit.load();
      expect(cubit.state.boardLevelIds, {'zip_1_01'});
      verify(() => leaderboard.myBoardLevelIds('zip')).called(1);
      await cubit.close();
    });

    test('a failure leaves them unknown and the map still shows', () async {
      when(
        () => leaderboard.myBoardLevelIds('zip'),
      ).thenThrow(Exception('offline'));
      final cubit = withBoard();
      await cubit.load();
      expect(cubit.state.status, LevelMapStatus.ready);
      expect(cubit.state.boardLevelIds, isNull);
      await cubit.close();
    });

    test('are reloaded after a clear changes the progress', () async {
      var ids = <String>{};
      when(
        () => leaderboard.myBoardLevelIds('zip'),
      ).thenAnswer((_) async => ids);
      final cubit = withBoard();
      await cubit.load();
      expect(cubit.state.boardLevelIds, isEmpty);
      ids = {'zip_1_01'};
      await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
      await pumpEventQueue();
      expect(cubit.state.boardLevelIds, {'zip_1_01'});
      verify(() => leaderboard.myBoardLevelIds('zip')).called(2);
      await cubit.close();
    });

    group('with the clear submitter', () {
      late _MockSubmitLevelClear submit;
      late StreamController<String> accepted;

      setUp(() {
        submit = _MockSubmitLevelClear();
        accepted = StreamController<String>.broadcast();
        when(() => submit.accepted).thenAnswer((_) => accepted.stream);
      });

      tearDown(() => accepted.close());

      LevelMapCubit withSubmit() => LevelMapCubit(
        worlds: worlds,
        progress: progress,
        leaderboard: leaderboard,
        submitLevelClear: submit,
      );

      test('a fresh clear reaches the ids once the Worker takes it', () async {
        // The board read on the progress change runs before the Worker
        // post lands, so it still sees the pre-clear board.
        when(
          () => leaderboard.myBoardLevelIds('zip'),
        ).thenAnswer((_) async => <String>{});
        final cubit = withSubmit();
        await cubit.load();
        await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
        await pumpEventQueue();
        expect(cubit.state.boardLevelIds, isEmpty);

        accepted.add('zip_1_01');
        await pumpEventQueue();
        expect(cubit.state.boardLevelIds, {'zip_1_01'});
        await cubit.close();
      });

      test(
        'an accepted clear while the ids are unknown reads them again',
        () async {
          final reads = <Completer<Set<String>?>>[];
          when(() => leaderboard.myBoardLevelIds('zip')).thenAnswer((_) {
            final read = Completer<Set<String>?>();
            reads.add(read);
            return read.future;
          });
          final cubit = withSubmit();
          unawaited(cubit.load());
          await pumpEventQueue();
          expect(reads, hasLength(1));

          accepted.add('zip_1_01');
          await pumpEventQueue();
          expect(reads, hasLength(2));
          // The first (pre-clear) read lands last and is dropped.
          reads[1].complete({'zip_1_01'});
          reads[0].complete(<String>{});
          await pumpEventQueue();
          expect(cubit.state.boardLevelIds, {'zip_1_01'});
          await cubit.close();
        },
      );

      test('a progress change forgets the ids until the read lands', () async {
        final reads = <Completer<Set<String>?>>[];
        when(() => leaderboard.myBoardLevelIds('zip')).thenAnswer((_) {
          final read = Completer<Set<String>?>();
          reads.add(read);
          return read.future;
        });
        final cubit = withSubmit();
        unawaited(cubit.load());
        await pumpEventQueue();
        reads[0].complete({'zip_1_01'});
        await pumpEventQueue();
        expect(cubit.state.boardLevelIds, {'zip_1_01'});

        // e.g. another account signed in: the old ids aren't theirs.
        await progress.record('zip', 'zip_1_02', stars: 1, seconds: 10);
        await pumpEventQueue();
        expect(cubit.state.boardLevelIds, isNull);
        reads[1].complete(<String>{});
        await pumpEventQueue();
        expect(cubit.state.boardLevelIds, isEmpty);
        await cubit.close();
      });

      test('stops listening when closed', () async {
        when(
          () => leaderboard.myBoardLevelIds('zip'),
        ).thenAnswer((_) async => <String>{});
        final cubit = withSubmit();
        await cubit.load();
        await cubit.close();
        expect(accepted.hasListener, isFalse);
      });
    });

    test('no repository means no ids', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.boardLevelIds, isNull);
      await cubit.close();
    });
  });
}
