import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/core/sfx/sfx_service.dart';
import 'package:winklo/data/repositories/play_mode_hint_quota_repository_impl.dart';
import 'package:winklo/domain/entities/in_progress_run.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/play_mode.dart';
import 'package:winklo/domain/play_mode_hints.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/in_progress_run_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/repositories/play_mode_record_repository.dart';
import 'package:winklo/domain/repositories/sfx_settings_repository.dart';
import 'package:winklo/domain/repositories/zip_level_repository.dart';
import 'package:winklo/domain/usecases/get_best_points.dart';
import 'package:winklo/domain/usecases/get_best_time_seconds.dart';
import 'package:winklo/domain/usecases/get_clear_board.dart';
import 'package:winklo/domain/usecases/is_new_personal_best.dart';
import 'package:winklo/domain/usecases/record_daily_clear.dart';
import 'package:winklo/domain/usecases/record_level_clear.dart';
import 'package:winklo/domain/usecases/submit_leaderboard_time.dart';
import 'package:winklo/domain/usecases/submit_score.dart';
import 'package:winklo/features/zip/view/zip_screen.dart';

import '../../../helpers/level_fixtures.dart';
import '../../../helpers/mock_analytics_repository.dart';

class _MockSubmitScore extends Mock implements SubmitScore {}

class _MockSubmitLeaderboardTime extends Mock
    implements SubmitLeaderboardTime {}

class _MockRecordDailyClear extends Mock implements RecordDailyClear {}

class _MockGetBestPoints extends Mock implements GetBestPoints {}

class _MockGetBestTimeSeconds extends Mock implements GetBestTimeSeconds {}

class _MockIsNewPersonalBest extends Mock implements IsNewPersonalBest {}

class _MockGetClearBoard extends Mock implements GetClearBoard {}

class _MockZipLevels extends Mock implements ZipLevelRepository {}

class _MockModeRecords extends Mock implements PlayModeRecordRepository {}

class _MockSfxSettings extends Mock implements SfxSettingsRepository {}

class _EmptyWorlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      LevelCatalog(const []);
}

class _Worlds implements LevelWorldRepository {
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async =>
      LevelCatalog([levelWorld(1, 3)]);
}

class _NoDrafts implements InProgressRunRepository {
  @override
  Future<InProgressRun?> load({
    required String gameId,
    required String playId,
  }) async => null;
  @override
  Future<void> save(InProgressRun run) async {}
  @override
  Future<void> clear({required String gameId, required String playId}) async {}
}

/// The repositories ZipScreen reads, around [child].
Future<Widget> withRepositories(
  Widget child, {
  LevelWorldRepository? worlds,
}) async {
  final analytics = MockAnalyticsRepository();
  stubAnalytics(analytics);
  final sfxSettings = _MockSfxSettings();
  when(() => sfxSettings.isEnabled).thenReturn(false);
  final quota = UnlimitedHintQuotaRepositoryImpl();
  SharedPreferences.setMockInitialValues({});
  final levelProgress = LevelProgressRepositoryImpl(
    await SharedPreferences.getInstance(),
    currentUid: () => 'u1',
  );
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<SfxService>.value(
        value: SfxService(settings: sfxSettings),
      ),
      RepositoryProvider<SubmitScore>.value(value: _MockSubmitScore()),
      RepositoryProvider<SubmitLeaderboardTime>.value(
        value: _MockSubmitLeaderboardTime(),
      ),
      RepositoryProvider<RecordDailyClear>.value(
        value: _MockRecordDailyClear(),
      ),
      RepositoryProvider<GetBestPoints>.value(value: _MockGetBestPoints()),
      RepositoryProvider<GetBestTimeSeconds>.value(
        value: _MockGetBestTimeSeconds(),
      ),
      RepositoryProvider<IsNewPersonalBest>.value(
        value: _MockIsNewPersonalBest(),
      ),
      RepositoryProvider<GetClearBoard>.value(value: _MockGetClearBoard()),
      RepositoryProvider<AnalyticsRepository>.value(value: analytics),
      RepositoryProvider<HintQuotaForMode>.value(
        value: HintQuotaForMode(
          daily: quota,
          archive: quota,
          practice: quota,
          level: quota,
        ),
      ),
      RepositoryProvider<InProgressRunRepository>.value(value: _NoDrafts()),
      RepositoryProvider<ZipLevelRepository>.value(value: _MockZipLevels()),
      RepositoryProvider<PlayModeRecordRepository>.value(
        value: _MockModeRecords(),
      ),
      RepositoryProvider<LevelWorldRepository>.value(
        value: worlds ?? _EmptyWorlds(),
      ),
      RepositoryProvider<LevelProgressRepository>.value(value: levelProgress),
      RepositoryProvider<RecordLevelClear>.value(
        value: RecordLevelClear(levelProgress, analytics),
      ),
    ],
    child: child,
  );
}

void main() {
  testWidgets('a level that is not in the catalog says so', (tester) async {
    await tester.pumpWidget(
      await withRepositories(
        const MaterialApp(home: ZipScreen(mode: PlayMode.level('zip_9_01'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this level.'), findsOneWidget);
    // Another load may work: Retry stays.
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  testWidgets('a locked level offers Map and no Retry', (tester) async {
    await tester.pumpWidget(
      await withRepositories(
        const MaterialApp(home: ZipScreen(mode: PlayMode.level('zip_1_03'))),
        worlds: _Worlds(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.levelLockedMessage), findsOneWidget);
    expect(find.text(AppStrings.retry), findsNothing);
    expect(find.text(AppStrings.levelBackToMap), findsOneWidget);
  });

  testWidgets('a failed level offers Map under Retry, back to the map', (
    tester,
  ) async {
    final visits = <(Uri, Object?)>[];
    final router = GoRouter(
      initialLocation: '/zip',
      routes: [
        GoRoute(
          path: '/zip',
          builder: (_, _) => const ZipScreen(mode: PlayMode.level('zip_9_01')),
        ),
        GoRoute(
          path: '/levels',
          builder: (_, state) {
            visits.add((state.uri, state.extra));
            return const Text('map');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      await withRepositories(MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    final retry = tester.getCenter(find.text(AppStrings.retry));
    final map = find.text(AppStrings.levelBackToMap);
    expect(map, findsOneWidget);
    expect(tester.getCenter(map).dy, greaterThan(retry.dy));

    await tester.tap(map);
    await tester.pumpAndSettle();
    expect(find.text('map'), findsOneWidget);
    expect(visits.single.$1.toString(), '/levels');
    // A fresh token, so the map is built anew.
    expect(visits.single.$2, isA<int>());
  });

  testWidgets('a failed level scrolls in a short window at 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      await withRepositories(
        const MaterialApp(home: ZipScreen(mode: PlayMode.level('zip_9_01'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(AppStrings.levelBackToMap), findsOneWidget);
  });
}
