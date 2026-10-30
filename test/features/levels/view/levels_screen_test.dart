import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/features/levels/view/levels_screen.dart';

import '../../../helpers/level_fixtures.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _Worlds implements LevelWorldRepository {
  _Worlds(this.value);
  final LevelCatalog? value;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async {
    final v = value;
    if (v == null) throw const LevelsUnavailable('offline');
    return v;
  }
}

void main() {
  late LevelProgressRepositoryImpl progress;
  late _MockAuth auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    auth = _MockAuth();
    when(() => auth.currentUser).thenReturn(null);
  });

  Future<void> pump(
    WidgetTester tester,
    LevelCatalog? catalog, {
    String? open,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => LevelsScreen(openLevelId: open),
        ),
        GoRoute(path: '/zip', builder: (_, _) => const Text('zip screen')),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LevelWorldRepository>.value(
            value: _Worlds(catalog),
          ),
          RepositoryProvider<LevelProgressRepository>.value(value: progress),
          RepositoryProvider<AuthRepository>.value(value: auth),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the map with the current level and stars total', (
    tester,
  ) async {
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pump(
      tester,
      LevelCatalog([levelWorld(1, 3), levelWorld(2, 2, theme: 'metro')]),
    );
    expect(find.text('Levels'), findsWidgets);
    expect(find.text('3 / 15'), findsOneWidget);
    expect(find.bySemanticsLabel('Level 2, next to play'), findsOneWidget);
    expect(find.text('World 2 · Metro'), findsOneWidget);
    expect(find.text('Clear Level 3 to open'), findsOneWidget);
  });

  testWidgets('tapping a locked level says what to clear first', (
    tester,
  ) async {
    await pump(tester, LevelCatalog([levelWorld(1, 3)]));
    await tester.tap(find.bySemanticsLabel('Level 3, locked'));
    await tester.pump();
    expect(find.text('Clear Level 1 first'), findsOneWidget);
  });

  testWidgets('tapping the current level opens its sheet', (tester) async {
    await pump(tester, LevelCatalog([levelWorld(1, 2)]));
    await tester.tap(find.bySemanticsLabel('Level 1, next to play'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets("open= opens that level's sheet once the map loads", (
    tester,
  ) async {
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pump(tester, LevelCatalog([levelWorld(1, 2)]), open: 'zip_1_02');
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('open= for a locked level says what to clear first', (
    tester,
  ) async {
    await pump(tester, LevelCatalog([levelWorld(1, 3)]), open: 'zip_1_03');
    expect(find.text('Clear Level 1 first'), findsOneWidget);
    expect(find.text('Play'), findsNothing);
  });

  testWidgets('offline first time: message and Retry', (tester) async {
    await pump(tester, null);
    expect(
      find.text('Levels need a connection the first time.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('no worlds yet', (tester) async {
    await pump(tester, LevelCatalog(const []));
    expect(find.text('Levels are coming soon.'), findsOneWidget);
  });
}
