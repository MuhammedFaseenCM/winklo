import 'package:bloc_test/bloc_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/game_tutorial_overlay.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/features/path_words/bloc/path_words_bloc.dart';
import 'package:winklo/features/path_words/bloc/path_words_event.dart';
import 'package:winklo/features/path_words/bloc/path_words_state.dart';
import 'package:winklo/features/path_words/view/path_words_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPathWordsBloc extends MockBloc<PathWordsEvent, PathWordsState>
    implements PathWordsBloc {}

class _MockTutorialRepository extends Mock implements TutorialRepository {}

PathWordsPuzzle _tinyPuzzle({required DateTime day}) {
  return PathWordsPuzzle(
    id: 't',
    day: day,
    size: 2,
    letters: const ['a', 'b', 'c', 'd'],
    targets: const [
      PathWordsTarget(
        id: 't0',
        word: 'ab',
        start: Cell(0, 0),
        path: [Cell(0, 0), Cell(0, 1)],
        colorIndex: 0,
      ),
    ],
  );
}

Future<void> _pumpScreen(WidgetTester tester, PathWordsState state) async {
  final bloc = _MockPathWordsBloc();
  when(() => bloc.state).thenReturn(state);
  whenListen(bloc, const Stream<PathWordsState>.empty(), initialState: state);
  final tutorials = _MockTutorialRepository();
  when(
    () => tutorials.hasSeen(GameIds.pathWords),
  ).thenAnswer((_) async => true);
  when(() => tutorials.markSeen(GameIds.pathWords)).thenAnswer((_) async {});
  await tester.pumpWidget(
    RepositoryProvider<TutorialRepository>.value(
      value: tutorials,
      child: MaterialApp(home: PathWordsScreen(bloc: bloc, autoStart: false)),
    ),
  );
  await tester.pump();
  await tester.pump();
  // Lets the board's entrance animations finish.
  await tester.pump(const Duration(seconds: 2));
}

OutlinedButton _undoButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text(AppStrings.pathWordsUndo),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const PathWordsEvent.pointerUp());
    registerFallbackValue(PathWordsState.initial(DateTime(2026, 1, 1)));
  });

  testWidgets('PathWordsScreen shows GameWidget when puzzle already ready', (
    tester,
  ) async {
    final day = DateTime(2026, 9, 17);
    final puzzle = _tinyPuzzle(day: day);
    final readyState = PathWordsState(
      day: day,
      puzzle: puzzle,
      status: PathWordsStatus.ready,
      resumedAt: day,
    );

    final bloc = _MockPathWordsBloc();
    when(() => bloc.state).thenReturn(readyState);
    whenListen(
      bloc,
      const Stream<PathWordsState>.empty(),
      initialState: readyState,
    );

    final tutorials = _MockTutorialRepository();
    when(
      () => tutorials.hasSeen(GameIds.pathWords),
    ).thenAnswer((_) async => true);
    when(() => tutorials.markSeen(GameIds.pathWords)).thenAnswer((_) async {});

    await tester.pumpWidget(
      RepositoryProvider<TutorialRepository>.value(
        value: tutorials,
        child: MaterialApp(home: PathWordsScreen(bloc: bloc, autoStart: false)),
      ),
    );

    // Self-heal path uses a post-frame callback.
    await tester.pump();
    await tester.pump();

    expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.pathWordsHowToPlayTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GameTutorialOverlay), findsOneWidget);
    expect(find.text(AppStrings.pathWordsTutorialMatchList), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  group('Undo', () {
    final day = DateTime(2026, 9, 17);
    const found = PathWordsStroke(
      cells: [Cell(0, 0), Cell(0, 1)],
      colorIndex: 0,
      targetId: 't0',
    );
    const wrong = PathWordsStroke(
      cells: [Cell(1, 0), Cell(1, 1)],
      colorIndex: 1,
    );

    testWidgets('is off when the board holds only found words', (tester) async {
      await _pumpScreen(
        tester,
        PathWordsState(
          day: day,
          puzzle: _tinyPuzzle(day: day),
          status: PathWordsStatus.playing,
          placedPaths: const [found],
          completedTargetIds: const {'t0'},
          resumedAt: day,
        ),
      );
      expect(_undoButton(tester).onPressed, isNull);
    });

    testWidgets('is on for a wrong stroke or a stroke being drawn', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        PathWordsState(
          day: day,
          puzzle: _tinyPuzzle(day: day),
          status: PathWordsStatus.playing,
          placedPaths: const [found, wrong],
          completedTargetIds: const {'t0'},
          resumedAt: day,
        ),
      );
      expect(_undoButton(tester).onPressed, isNotNull);

      await _pumpScreen(
        tester,
        PathWordsState(
          day: day,
          puzzle: _tinyPuzzle(day: day),
          status: PathWordsStatus.playing,
          activePath: const [Cell(1, 0)],
          resumedAt: day,
        ),
      );
      expect(_undoButton(tester).onPressed, isNotNull);
    });
  });
}
