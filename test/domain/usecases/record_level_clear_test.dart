import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/usecases/record_level_clear.dart';

import '../../helpers/level_fixtures.dart';
import '../../helpers/mock_analytics_repository.dart';

void main() {
  late LevelProgressRepositoryImpl progress;
  late MockAnalyticsRepository analytics;
  late RecordLevelClear record;
  final catalog = LevelCatalog([levelWorld(1, 3), levelWorld(2, 2)]);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    analytics = MockAnalyticsRepository();
    stubAnalytics(analytics);
    record = RecordLevelClear(progress, analytics);
  });

  test('scores the run, keeps it and logs it', () async {
    final slot = catalog.slot('zip_2_01')!;
    final result = await record(
      game: 'zip',
      slot: slot,
      usedHints: false,
      seconds: 25,
    );
    expect(result.runStars, 3);
    expect(progress.progress('zip')['zip_2_01']!.stars, 3);
    verify(
      () => analytics.logLevelCleared(
        gameId: 'zip',
        levelId: 'zip_2_01',
        world: 2,
        number: 4,
        stars: 3,
        firstClear: true,
        improved: false,
      ),
    ).called(1);
  });

  test('a hinted, slow run earns one star', () async {
    final result = await record(
      game: 'zip',
      slot: catalog.slot('zip_1_01')!,
      usedHints: true,
      seconds: 90,
    );
    expect(result.runStars, 1);
  });
}
