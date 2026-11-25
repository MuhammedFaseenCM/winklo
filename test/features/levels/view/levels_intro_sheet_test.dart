import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/levels_game_preference_repository.dart';
import 'package:winklo/domain/repositories/levels_intro_repository.dart';
import 'package:winklo/domain/usecases/get_levels_overview.dart';
import 'package:winklo/features/levels/view/widgets/levels_intro_sheet.dart';

class _Intro extends Mock implements LevelsIntroRepository {}

class _Analytics extends Mock implements AnalyticsRepository {}

class _Overview extends Mock implements GetLevelsOverview {}

class _Pref extends Mock implements LevelsGamePreferenceRepository {}

GameLevelsOverview game(String id, String next, int number) =>
    GameLevelsOverview(
      gameId: id,
      nextLevelId: next,
      nextNumber: number,
      stars: 0,
      maxStars: 60,
      allCleared: false,
    );

void main() {
  late _Intro intro;
  late _Analytics analytics;
  late _Overview overview;
  late _Pref pref;
  late List<String> visited;

  setUp(() {
    intro = _Intro();
    analytics = _Analytics();
    overview = _Overview();
    pref = _Pref();
    visited = [];
    when(() => intro.setLastGame(any())).thenAnswer((_) async {});
    when(() => pref.write(any())).thenAnswer((_) async {});
    when(
      () => analytics.logLevelsIntro(
        action: any(named: 'action'),
        gameId: any(named: 'gameId'),
      ),
    ).thenAnswer((_) async {});
    when(() => overview()).thenAnswer(
      (_) async => LevelsOverview({
        GameIds.zip: game(GameIds.zip, 'zip_1_01', 1),
        GameIds.pathWords: game(GameIds.pathWords, 'path_words_1_04', 4),
      }),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => showLevelsIntro(context),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/levels',
          builder: (_, state) {
            visited.add(state.uri.toString());
            return const Text('levels');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LevelsIntroRepository>.value(value: intro),
          RepositoryProvider<AnalyticsRepository>.value(value: analytics),
          RepositoryProvider<GetLevelsOverview>.value(value: overview),
          RepositoryProvider<LevelsGamePreferenceRepository>.value(value: pref),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers both games at their next level', (tester) async {
    await pump(tester);
    expect(find.text(AppStrings.levelsIntroTitle), findsOneWidget);
    expect(find.text(AppStrings.zipTitle), findsOneWidget);
    expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.text(AppStrings.levelNumber(1)), findsOneWidget);
    expect(find.text(AppStrings.levelNumber(4)), findsOneWidget);
  });

  testWidgets('Play opens that level on its game\'s map', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.levelNumber(4)));
    await tester.pumpAndSettle();
    expect(visited, ['/levels?open=path_words_1_04']);
    verify(() => intro.setLastGame(GameIds.pathWords)).called(1);
    verify(
      () => analytics.logLevelsIntro(action: 'play', gameId: GameIds.pathWords),
    ).called(1);
  });

  testWidgets('Maybe later closes it', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.levelsIntroLater));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelsIntroTitle), findsNothing);
    expect(visited, isEmpty);
    verify(() => analytics.logLevelsIntro(action: 'later')).called(1);
  });

  testWidgets('offline it still offers Level 1 of each, opening the map', (
    tester,
  ) async {
    when(() => overview()).thenAnswer((_) async => const LevelsOverview({}));
    await pump(tester);
    expect(find.text(AppStrings.levelNumber(1)), findsNWidgets(2));
    await tester.tap(find.text(AppStrings.levelNumber(1)).last);
    await tester.pumpAndSettle();
    expect(visited, ['/levels']);
    verify(() => pref.write(GameIds.pathWords)).called(1);
  });
}
