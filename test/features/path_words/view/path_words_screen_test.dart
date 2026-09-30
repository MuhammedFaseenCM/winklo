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
      startedAt: day,
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
}
