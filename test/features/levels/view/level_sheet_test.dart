import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/level_progress.dart';
import 'package:winklo/domain/logic/level_catalog.dart';
import 'package:winklo/domain/logic/level_map.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/levels/view/widgets/level_sheet.dart';

import '../../../helpers/level_fixtures.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  final map = LevelMap.build(
    LevelCatalog([levelWorld(1, 2)]),
    const LevelProgress({'zip_1_01': LevelRecord(stars: 2, bestSeconds: 17)}),
  );

  Future<List<String>> openSheet(
    WidgetTester tester,
    String id, {
    LevelMap? from,
    double textScale = 1,
    Set<String>? boardLevelIds,
  }) async {
    final m = from ?? map;
    final visited = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLevelSheet(
                  context,
                  m.node(id)!,
                  boardLevelIds: boardLevelIds,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/path-words',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const SizedBox();
          },
        ),
        GoRoute(
          path: '/zip',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const SizedBox();
          },
        ),
      ],
    );
    final auth = _MockAuth();
    const user = AppUser(uid: 'u1', displayName: 'Ada');
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => AuthCubit(
          authRepository: auth,
          signInWithGoogle: _MockSignInWithGoogle(),
          signOut: _MockSignOut(),
        ),
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return visited;
  }

  testWidgets('a cleared level: world, number, best time, goals, Replay', (
    tester,
  ) async {
    final visited = await openSheet(tester, 'zip_1_01');
    expect(find.text('World 1 · Ink'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('3 × 3'), findsOneWidget);
    expect(find.text('Best 0:17'), findsOneWidget);
    expect(find.text('STAR GOALS'), findsOneWidget);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.text('No hints'), findsOneWidget);
    expect(find.text('0:30 or less'), findsOneWidget);
    expect(find.bySemanticsLabel('2 of 3 stars'), findsOneWidget);
    await tester.tap(find.text('Replay'));
    await tester.pumpAndSettle();
    expect(visited, ['/zip?mode=level&level=zip_1_01']);
  });

  testWidgets('Play on a Path Words level opens its game', (tester) async {
    final pathWords = LevelMap.build(
      LevelCatalog([pathWordsWorld(1, 2)]),
      const LevelProgress({}),
    );
    final visited = await openSheet(tester, 'path_words_1_01', from: pathWords);
    expect(find.text('3 × 3'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(visited, ['/path-words?mode=level&level=path_words_1_01']);
  });

  testWidgets('the current level says Play', (tester) async {
    await openSheet(tester, 'zip_1_02');
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('3 × 3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'of \d stars')), findsNothing);
  });

  testWidgets('a level without a target shows no time goal', (tester) async {
    final noTarget = LevelMap.build(
      LevelCatalog([levelWorld(1, 2, targetSeconds: null)]),
      const LevelProgress({}),
    );
    await openSheet(tester, 'zip_1_01', from: noTarget);
    expect(find.text('Clear the board'), findsOneWidget);
    expect(find.textContaining('or less'), findsNothing);
  });

  group('the not-on-the-board line', () {
    final line = find.text('Not on the board yet · replay to count');

    testWidgets('shows for a cleared level the board lacks', (tester) async {
      await openSheet(tester, 'zip_1_01', boardLevelIds: {'zip_1_02'});
      expect(line, findsOneWidget);
    });

    testWidgets('is absent for a level the board holds', (tester) async {
      await openSheet(tester, 'zip_1_01', boardLevelIds: {'zip_1_01'});
      expect(line, findsNothing);
    });

    testWidgets('is absent for an uncleared level', (tester) async {
      await openSheet(tester, 'zip_1_02', boardLevelIds: <String>{});
      expect(line, findsNothing);
    });

    testWidgets('is absent when the board is unknown', (tester) async {
      await openSheet(tester, 'zip_1_01');
      expect(line, findsNothing);
    });
  });

  testWidgets('large text opens without an exception', (tester) async {
    await openSheet(tester, 'zip_1_01', textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
