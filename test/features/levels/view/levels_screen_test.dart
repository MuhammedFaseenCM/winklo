import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';
import 'package:winklo/features/levels/view/levels_screen.dart';
import 'package:winklo/features/levels/view/widgets/level_avatar_pin.dart';
import 'package:winklo/features/levels/view/widgets/level_node.dart';

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
    bool dock = false,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) {
            final screen = LevelsScreen(openLevelId: open);
            if (!dock) return screen;
            // The dashboard shell's frame: the tab under the floating dock.
            return Scaffold(
              extendBody: true,
              body: screen,
              bottomNavigationBar: FloatingNavDock(
                selectedIndex: 1,
                onDestinationSelected: (_) {},
              ),
            );
          },
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

  Future<void> clear(Iterable<int> numbers, {int stars = 3}) async {
    for (final n in numbers) {
      await progress.record('zip', levelId(1, n), stars: stars, seconds: 10);
    }
  }

  Future<void> phone(WidgetTester tester, {double width = 390}) async {
    await tester.binding.setSurfaceSize(Size(width, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  /// The centre of Level [number]'s circle.
  Offset circleOf(WidgetTester tester, int number) {
    final node = find.byWidgetPredicate(
      (w) => w is LevelNode && w.node.slot.number == number,
    );
    return tester.getTopLeft(node) +
        const Offset(LevelNode.width / 2, LevelNode.diameter / 2);
  }

  Rect viewport(WidgetTester tester) =>
      tester.getRect(find.byType(SingleChildScrollView));

  testWidgets('scrolls so the current level sits mid-view', (tester) async {
    await phone(tester);
    await clear([for (var n = 1; n <= 20; n++) n]);
    await pump(tester, LevelCatalog([levelWorld(1, 30)]));
    expect(circleOf(tester, 21).dy, closeTo(viewport(tester).center.dy, 40));
  });

  testWidgets('with every level cleared, shows the last one', (tester) async {
    await phone(tester);
    await clear([for (var n = 1; n <= 30; n++) n]);
    await pump(tester, LevelCatalog([levelWorld(1, 30)]));
    expect(viewport(tester).contains(circleOf(tester, 30)), isTrue);
  });

  testWidgets(
    'open= for a level not on the map shows the current one, no sheet',
    (tester) async {
      await phone(tester);
      await clear([for (var n = 1; n <= 20; n++) n]);
      await pump(tester, LevelCatalog([levelWorld(1, 30)]), open: 'zip_9_99');
      expect(circleOf(tester, 21).dy, closeTo(viewport(tester).center.dy, 1));
      expect(find.text('Play'), findsNothing);
    },
  );

  testWidgets('moves to the new current level when it changes', (tester) async {
    await phone(tester);
    await clear([for (var n = 1; n <= 9; n++) n]);
    await pump(tester, LevelCatalog([levelWorld(1, 30)]));
    expect(circleOf(tester, 10).dy, closeTo(viewport(tester).center.dy, 1));
    await clear([10]);
    await tester.pumpAndSettle();
    expect(circleOf(tester, 11).dy, closeTo(viewport(tester).center.dy, 1));
  });

  testWidgets('a re-emit with the same current level leaves the view', (
    tester,
  ) async {
    await phone(tester);
    await clear([for (var n = 1; n <= 9; n++) n], stars: 2);
    await pump(tester, LevelCatalog([levelWorld(1, 30)]));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 150));
    await tester.pumpAndSettle();
    final before = circleOf(tester, 10);
    await clear([1]);
    await tester.pumpAndSettle();
    expect(find.text('19 / 90'), findsOneWidget);
    expect(circleOf(tester, 10), before);
  });

  for (final below in [3, 4]) {
    testWidgets(
      'a long Malayalam world label at 1.3x on a 320 px phone keeps clear '
      'of the pin and stays in its half ($below levels below)',
      (tester) async {
        AppStrings.use('ml');
        addTearDown(() => AppStrings.use('en'));
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await phone(tester, width: 320);
        await clear([for (var n = 1; n < below; n++) n]);
        await pump(
          tester,
          LevelCatalog([
            levelWorld(1, below),
            levelWorld(2, 3, theme: 'metro'),
          ]),
        );
        expect(tester.takeException(), isNull);
        final label = tester.getRect(
          find
              .ancestor(
                of: find.text(AppStrings.levelWorldTitle(2, 'metro')),
                matching: find.byType(Container),
              )
              .first,
        );
        final pin = tester.getRect(find.byType(LevelAvatarPin));
        expect(label.overlaps(pin), isFalse, reason: '$label vs pin $pin');
        const half = 320 / 2;
        expect(
          label.right <= half + 4 || label.left >= half,
          isTrue,
          reason: '$label',
        );
        expect(label.left, greaterThanOrEqualTo(0));
        expect(label.right, lessThanOrEqualTo(320));
      },
    );
  }

  group('under the shell dock', () {
    double dockTop(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('floating_nav_dock'))).top;

    Rect nodeRect(WidgetTester tester, int number) => tester.getRect(
      find.byWidgetPredicate(
        (w) => w is LevelNode && w.node.slot.number == number,
      ),
    );

    testWidgets('the map runs under it, Level 1 and its world label above', (
      tester,
    ) async {
      await phone(tester);
      await pump(
        tester,
        LevelCatalog([levelWorld(1, 4), levelWorld(2, 3, theme: 'metro')]),
        dock: true,
      );
      final top = dockTop(tester);
      expect(top, lessThan(844 - 60));
      expect(viewport(tester).bottom, 844);
      expect(nodeRect(tester, 1).bottom, lessThanOrEqualTo(top - 8));
      final label = tester.getRect(
        find.text(AppStrings.levelWorldTitle(1, 'ink')),
      );
      expect(label.bottom, lessThanOrEqualTo(top));
    });

    testWidgets('the current level sits mid-way down the part it leaves', (
      tester,
    ) async {
      await phone(tester);
      await clear([for (var n = 1; n <= 20; n++) n]);
      await pump(tester, LevelCatalog([levelWorld(1, 30)]), dock: true);
      final visible = (viewport(tester).top + dockTop(tester)) / 2;
      expect(circleOf(tester, 21).dy, closeTo(visible, 1));
    });
  });
}
