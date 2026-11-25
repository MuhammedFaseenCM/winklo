import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/level_progress_repository.dart';
import 'package:winklo/domain/repositories/levels_intro_repository.dart';
import 'package:winklo/domain/usecases/get_levels_overview.dart';
import 'package:winklo/features/home/view/widgets/home_levels_entry.dart';
import 'package:winklo/features/home/view/widgets/home_more_play_entry.dart';

class _Intro extends Mock implements LevelsIntroRepository {}

class _Overview extends Mock implements GetLevelsOverview {}

class _Progress extends Mock implements LevelProgressRepository {}

GameLevelsOverview game(String id, String next, int number, int stars) =>
    GameLevelsOverview(
      gameId: id,
      nextLevelId: next,
      nextNumber: number,
      stars: stars,
      maxStars: 60,
      allCleared: false,
    );

void main() {
  late _Intro intro;
  late _Overview overview;
  late _Progress progress;
  late List<String> visited;

  setUp(() {
    intro = _Intro();
    overview = _Overview();
    progress = _Progress();
    visited = [];
    when(() => intro.lastGame).thenReturn(null);
    when(() => intro.changes).thenAnswer((_) => const Stream.empty());
    when(() => progress.changes).thenAnswer((_) => const Stream.empty());
    when(() => overview()).thenAnswer(
      (_) async => LevelsOverview({
        GameIds.zip: game(GameIds.zip, 'zip_2_09', 9, 23),
        GameIds.pathWords: game(GameIds.pathWords, 'path_words_1_04', 4, 7),
      }),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Column(children: [HomeLevelsEntry(), HomeMorePlayEntry()]),
          ),
        ),
        GoRoute(
          path: '/levels',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Text('levels');
          },
        ),
        GoRoute(path: '/more', builder: (_, _) => const Text('more')),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LevelsIntroRepository>.value(value: intro),
          RepositoryProvider<GetLevelsOverview>.value(value: overview),
          RepositoryProvider<LevelProgressRepository>.value(value: progress),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows all stars and continues Path Words by default', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(AppStrings.levelsTitle), findsOneWidget);
    expect(find.textContaining('30'), findsOneWidget);
    expect(
      find.textContaining(
        AppStrings.levelsHomeContinue(AppStrings.pathWordsTitle, 4),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(HomeLevelsEntry));
    await tester.pumpAndSettle();
    expect(visited, ['/levels?open=path_words_1_04']);
  });

  testWidgets('continues the game last played', (tester) async {
    when(() => intro.lastGame).thenReturn(GameIds.zip);
    await pump(tester);
    expect(
      find.textContaining(
        AppStrings.levelsHomeContinue(AppStrings.zipTitle, 9),
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline it still opens the Levels tab', (tester) async {
    when(() => overview()).thenAnswer((_) async => const LevelsOverview({}));
    await pump(tester);
    await tester.tap(find.byType(HomeLevelsEntry));
    await tester.pumpAndSettle();
    expect(visited, ['/levels']);
  });

  testWidgets('it is no taller than More ways to play', (tester) async {
    await pump(tester);
    expect(
      tester.getSize(find.byType(HomeLevelsEntry)).height,
      lessThanOrEqualTo(tester.getSize(find.byType(HomeMorePlayEntry)).height),
    );
  });
}
