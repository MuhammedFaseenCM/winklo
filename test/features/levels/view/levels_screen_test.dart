import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/data/repositories/level_progress_repository_impl.dart';
import 'package:winklo/data/repositories/levels_game_preference_repository_impl.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/level_world.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/leaderboard_repository.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/level_world_repository.dart';
import 'package:winklo/domain/repositories/levels_game_preference_repository.dart';
import 'package:winklo/domain/repositories/levels_intro_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/submit_level_clear.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';
import 'package:winklo/features/levels/view/levels_screen.dart';
import 'package:winklo/features/levels/view/widgets/level_avatar_pin.dart';
import 'package:winklo/features/levels/view/widgets/level_node.dart';

import '../../../helpers/level_fixtures.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockLeaderboard extends Mock implements LeaderboardRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockSubmitLevelClear extends Mock implements SubmitLevelClear {}

class _Pref implements LevelsGamePreferenceRepository {
  _Pref([this.game = 'zip']);
  String game;
  final writes = <String>[];
  @override
  String read() => game;
  @override
  Future<void> write(String gameId) async {
    game = gameId;
    writes.add(gameId);
  }
}

class _Worlds implements LevelWorldRepository {
  _Worlds(this.value, [this.pathWords, this.zipGate]);
  final LevelCatalog? value;
  final LevelCatalog? pathWords;

  /// Holds Zip's catalog back until it completes (a slow network).
  final Completer<void>? zipGate;
  @override
  Future<LevelCatalog> catalog(String game, {bool refresh = false}) async {
    if (game != 'path_words') await zipGate?.future;
    final v = game == 'path_words' ? pathWords : value;
    if (v == null) throw const LevelsUnavailable('offline');
    return v;
  }
}

class _MockIntro extends Mock implements LevelsIntroRepository {}

void main() {
  late LevelProgressRepositoryImpl progress;
  late _MockAuth auth;
  late _MockLeaderboard leaderboard;
  late _MockSubmitLevelClear submit;
  late StreamController<String> accepted;
  late List<String> visited;
  late List<Object?> visitedExtras;
  late _Pref pref;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    progress = LevelProgressRepositoryImpl(
      await SharedPreferences.getInstance(),
      currentUid: () => 'u1',
    );
    auth = _MockAuth();
    leaderboard = _MockLeaderboard();
    when(
      () => leaderboard.myBoardLevelIds(any()),
    ).thenAnswer((_) async => null);
    submit = _MockSubmitLevelClear();
    accepted = StreamController<String>.broadcast();
    addTearDown(accepted.close);
    when(() => submit.accepted).thenAnswer((_) => accepted.stream);
    visited = [];
    visitedExtras = [];
    pref = _Pref();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
  });

  Future<void> pump(
    WidgetTester tester,
    LevelCatalog? catalog, {
    String? open,
    bool dock = false,
    LevelCatalog? pathWords,
    Completer<void>? zipGate,
    bool settle = true,
    LevelsIntroRepository? intro,
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
        GoRoute(
          path: '/path-words',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Text('path words screen');
          },
        ),
        GoRoute(
          path: '/leaderboard',
          builder: (_, state) {
            visited.add(state.uri.toString());
            visitedExtras.add(state.extra);
            return const Text('board screen');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LevelWorldRepository>.value(
            value: _Worlds(catalog, pathWords, zipGate),
          ),
          RepositoryProvider<LevelsGamePreferenceRepository>.value(value: pref),
          RepositoryProvider<LevelProgressRepository>.value(value: progress),
          RepositoryProvider<AuthRepository>.value(value: auth),
          RepositoryProvider<LeaderboardRepository>.value(value: leaderboard),
          RepositoryProvider<SubmitLevelClear>.value(value: submit),
          if (intro != null)
            RepositoryProvider<LevelsIntroRepository>.value(value: intro),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
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
    expect(find.text('World 2 · Metro · 3 × 3'), findsOneWidget);
    expect(find.text('Clear Level 3 to open'), findsOneWidget);
  });

  testWidgets('the star total opens the Levels board', (tester) async {
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pump(tester, LevelCatalog([levelWorld(1, 3)]));
    final link = find.bySemanticsLabel(AppStrings.levelsStarsToBoard);
    expect(link, findsOneWidget);
    expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('3 / 9'));
    await tester.pumpAndSettle();
    expect(visited, ['/leaderboard?game=zip&board=levels']);
  });

  testWidgets('a cleared level missing from the board says so in its sheet', (
    tester,
  ) async {
    when(
      () => leaderboard.myBoardLevelIds('zip'),
    ).thenAnswer((_) async => {'zip_1_02'});
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await pump(tester, LevelCatalog([levelWorld(1, 3)]));
    await tester.tap(find.bySemanticsLabel(RegExp('Level 1')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelSheetNotOnBoard), findsOneWidget);
  });

  testWidgets('a fresh clear the Worker takes is not flagged in its sheet', (
    tester,
  ) async {
    // The board read on the clear's progress change runs before the post
    // lands: it still sees the board without the level.
    when(
      () => leaderboard.myBoardLevelIds('zip'),
    ).thenAnswer((_) async => <String>{});
    await pump(tester, LevelCatalog([levelWorld(1, 3)]));
    await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
    await tester.pumpAndSettle();
    accepted.add('zip_1_01');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('Level 1')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelSheetNotOnBoard), findsNothing);
  });

  /// World 2, Metro, whose boards are [size] wide (no size when null).
  LevelWorld metroOfSize(int? size) {
    final json = levelWorldJson(2, 2, theme: 'metro');
    json['levels'] = [
      for (final level in json['levels'] as List)
        {
          for (final e in (level as Map<String, dynamic>).entries)
            if (e.key != 'size') e.key: e.value,
          'size': ?size,
        },
    ];
    return LevelWorld.fromJson('zip_2', json);
  }

  testWidgets("a locked world's label says its board size", (tester) async {
    await pump(tester, LevelCatalog([levelWorld(1, 3), metroOfSize(5)]));
    expect(find.text('World 2 · Metro · 5 × 5'), findsOneWidget);
    // An open world doesn't.
    expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsOneWidget);
  });

  testWidgets('a locked world of unknown size says no size', (tester) async {
    await pump(tester, LevelCatalog([levelWorld(1, 3), metroOfSize(null)]));
    expect(find.text('World 2 · Metro'), findsOneWidget);
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
                of: find.textContaining(
                  AppStrings.levelWorldTitle(
                    2,
                    AppStrings.levelWorldName('metro'),
                  ),
                ),
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

  group('the game switcher', () {
    final animals = LevelCatalog([pathWordsWorld(1, 3)]);

    testWidgets('Path Words shows its map and is remembered', (tester) async {
      await pump(tester, LevelCatalog([levelWorld(1, 3)]), pathWords: animals);
      expect(find.text('Sudoku · Soon'), findsOneWidget);
      await tester.tap(find.text('Sudoku · Soon'));
      await tester.pumpAndSettle();
      expect(pref.writes, isEmpty);
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.levelWorldTitle(1, 'Animals')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsNothing);
      expect(pref.writes, ['path_words']);
    });

    testWidgets('opens on the remembered game', (tester) async {
      pref = _Pref('path_words');
      await pump(tester, LevelCatalog([levelWorld(1, 3)]), pathWords: animals);
      expect(
        find.text(AppStrings.levelWorldTitle(1, 'Animals')),
        findsOneWidget,
      );
    });

    testWidgets('the star link follows the game', (tester) async {
      pref = _Pref('path_words');
      await progress.record(
        'path_words',
        'path_words_1_01',
        stars: 2,
        seconds: 10,
      );
      await pump(tester, LevelCatalog([levelWorld(1, 3)]), pathWords: animals);
      await tester.tap(find.text('2 / 9'));
      await tester.pumpAndSettle();
      expect(visited, ['/leaderboard?game=path_words&board=levels']);
      expect(visitedExtras, [isA<int>()]);
    });

    testWidgets('each game has its own stars', (tester) async {
      await progress.record('zip', 'zip_1_01', stars: 3, seconds: 10);
      await progress.record(
        'path_words',
        'path_words_1_01',
        stars: 1,
        seconds: 10,
      );
      await pump(tester, LevelCatalog([levelWorld(1, 3)]), pathWords: animals);
      expect(find.text('3 / 9'), findsOneWidget);
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pumpAndSettle();
      expect(find.text('1 / 9'), findsOneWidget);
      await tester.tap(find.text(AppStrings.zipTitle));
      await tester.pumpAndSettle();
      expect(find.text('3 / 9'), findsOneWidget);
    });

    testWidgets('an open= id picks its game and opens its sheet', (
      tester,
    ) async {
      await pump(
        tester,
        LevelCatalog([levelWorld(1, 3)]),
        pathWords: animals,
        open: 'path_words_1_01',
      );
      expect(find.text(AppStrings.levelWorldTitle(1, 'Animals')), findsWidgets);
      expect(find.text('Play'), findsOneWidget);
      expect(pref.writes, ['path_words']);
    });

    testWidgets('a consumed open= id does not reopen after switching back', (
      tester,
    ) async {
      await pump(
        tester,
        LevelCatalog([levelWorld(1, 3)]),
        pathWords: animals,
        open: 'path_words_1_01',
      );
      expect(find.text('Play'), findsOneWidget);
      Navigator.of(tester.element(find.text('Play'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsNothing);
      await tester.tap(find.text(AppStrings.zipTitle));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsWidgets);
      expect(find.text('Play'), findsNothing);
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.levelWorldTitle(1, 'Animals')), findsWidgets);
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('a zip open= id beats a stored Path Words choice', (
      tester,
    ) async {
      pref = _Pref('path_words');
      await pump(
        tester,
        LevelCatalog([levelWorld(1, 3)]),
        pathWords: animals,
        open: 'zip_1_01',
      );
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsWidgets);
      expect(find.text(AppStrings.levelWorldTitle(1, 'Animals')), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      expect(pref.writes, ['zip']);
    });

    testWidgets('a stored game without Levels opens Zip', (tester) async {
      SharedPreferences.setMockInitialValues({
        'levels_selected_game': 'sudoku',
      });
      pref = _Pref(
        LevelsGamePreferenceRepositoryImpl(
          await SharedPreferences.getInstance(),
        ).read(),
      );
      await pump(tester, LevelCatalog([levelWorld(1, 3)]), pathWords: animals);
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsOneWidget);
    });

    testWidgets('a Path Words level plays in Path Words', (tester) async {
      pref = _Pref('path_words');
      const user = AppUser(uid: 'u1', displayName: 'Ada');
      when(() => auth.currentUser).thenReturn(user);
      when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
      await pump(tester, LevelCatalog([levelWorld(1, 3)]), pathWords: animals);
      await tester.tap(find.bySemanticsLabel(RegExp('Level 1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(visited, ['/path-words?mode=level&level=path_words_1_01']);
    });
  });

  group('under the shell dock', () {
    double dockTop(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('floating_nav_dock'))).top;

    testWidgets('the current world\'s label stays clear of the dock', (
      tester,
    ) async {
      await phone(tester);
      await clear([1, 2, 3, 4]);
      for (var n = 1; n <= 4; n++) {
        await progress.record('zip', levelId(2, n), stars: 3, seconds: 10);
      }
      await pump(
        tester,
        LevelCatalog([levelWorld(1, 4), levelWorld(2, 12, theme: 'metro')]),
        dock: true,
      );
      final label = tester.getRect(
        find
            .ancestor(
              of: find.textContaining(
                AppStrings.levelWorldTitle(
                  2,
                  AppStrings.levelWorldName('metro'),
                ),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        label.bottom,
        lessThanOrEqualTo(dockTop(tester)),
        reason: '$label',
      );
    });

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
        find.text(AppStrings.levelWorldTitle(1, 'Ink')),
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

  testWidgets('a locked Path Words world says its size range', (tester) async {
    pref = _Pref('path_words');
    await pump(
      tester,
      LevelCatalog([levelWorld(1, 3)]),
      pathWords: LevelCatalog([
        pathWordsWorld(1, 3),
        pathWordsWorld(2, 4, theme: 'food', title: 'Food', sizes: [3, 4, 6]),
      ]),
    );
    expect(find.textContaining('3 × 3 – 6 × 6'), findsOneWidget);
  });

  testWidgets('opening the Levels tab clears its new dot', (tester) async {
    final intro = _MockIntro();
    when(() => intro.markLevelsTabSeen()).thenAnswer((_) async {});
    when(() => intro.levelsTabSeen).thenReturn(false);
    await pump(tester, LevelCatalog([levelWorld(1, 3)]), intro: intro);
    verify(() => intro.markLevelsTabSeen()).called(1);
  });

  group('the header and the switch', () {
    final zip = LevelCatalog([levelWorld(1, 3)]);
    final animals = LevelCatalog([pathWordsWorld(1, 3)]);
    String sudoku() => '${AppStrings.sudokuTitle} · ${AppStrings.levelsSoon}';

    testWidgets('the game chips read Zip and Path Words', (tester) async {
      await pump(tester, zip, pathWords: animals);
      expect(find.text(AppStrings.zipTitle), findsOneWidget);
      expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    });

    testWidgets('the Sudoku chip lines up with the game chips', (tester) async {
      await pump(tester, zip, pathWords: animals);
      final zipText = tester.getCenter(find.text(AppStrings.zipTitle));
      final sudokuText = tester.getCenter(find.text(sudoku()));
      expect(sudokuText.dy, closeTo(zipText.dy, 0.5));
    });

    testWidgets('the Sudoku chip is a disabled button that says it is coming', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, zip, pathWords: animals);
      expect(
        tester.getSemantics(find.bySemanticsLabel(sudoku())),
        matchesSemantics(
          label: sudoku(),
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text(sudoku()));
      await tester.pump();
      expect(find.text(AppStrings.levelsSudokuSoon), findsOneWidget);
      expect(pref.writes, isEmpty);
      handle.dispose();
    });

    testWidgets('switching slides the map across', (tester) async {
      await pump(tester, zip, pathWords: animals);
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsNothing);
      expect(
        find.text(AppStrings.levelWorldTitle(1, 'Animals')),
        findsOneWidget,
      );
    });

    testWidgets('with reduce motion the switch is instant', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pump(tester, zip, pathWords: animals);
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pump();
      await tester.pump();
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsNothing);
    });

    testWidgets('rapid switching settles on the last chip', (tester) async {
      await pump(tester, zip, pathWords: animals);
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text(AppStrings.zipTitle), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(
        find.text(AppStrings.pathWordsTitle),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings.levelWorldTitle(1, 'Animals')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.levelWorldTitle(1, 'Ink')), findsNothing);
      expect(pref.writes.last, 'path_words');
    });

    testWidgets('a map switched away from never opens its deep-linked sheet', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pump(
        tester,
        zip,
        pathWords: animals,
        open: levelId(1, 1),
        zipGate: gate,
        settle: false,
      );
      await tester.pump();
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pump(const Duration(milliseconds: 50));
      // Zip's worlds land while its map is still sliding away.
      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('the map sliding away takes no taps', (tester) async {
      await pump(tester, zip, pathWords: animals);
      final level1 = tester.getCenter(find.bySemanticsLabel(RegExp('Level 1')));
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(level1);
      await tester.pumpAndSettle();
      expect(find.textContaining('World 1 · Ink'), findsNothing);
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('the chips stay put while the new map loads', (tester) async {
      await pump(tester, zip, pathWords: animals);
      final before = tester.getCenter(find.text(AppStrings.zipTitle)).dy;
      await tester.tap(find.text(AppStrings.pathWordsTitle));
      await tester.pump();
      expect(tester.getCenter(find.text(AppStrings.zipTitle)).dy, before);
    });

    testWidgets('the chips do not overflow at twice the text size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, zip, pathWords: animals);
      expect(tester.takeException(), isNull);
    });
  });
}
