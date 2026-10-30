import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
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
}
