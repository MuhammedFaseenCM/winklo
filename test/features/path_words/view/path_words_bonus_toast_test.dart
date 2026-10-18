import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/features/path_words/bloc/path_words_bloc.dart';
import 'package:winklo/features/path_words/bloc/path_words_event.dart';
import 'package:winklo/features/path_words/bloc/path_words_state.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_bonus_toast.dart';

class _MockPathWordsBloc extends MockBloc<PathWordsEvent, PathWordsState>
    implements PathWordsBloc {}

void main() {
  final day = DateTime(2026, 9, 17);
  final puzzle = PathWordsPuzzle(
    id: 'p',
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

  testWidgets('says "Bonus word: STARE" for each new bonus word only', (
    tester,
  ) async {
    final playing = PathWordsState(
      day: day,
      puzzle: puzzle,
      status: PathWordsStatus.playing,
    );
    final states = StreamController<PathWordsState>();
    addTearDown(states.close);
    final bloc = _MockPathWordsBloc();
    whenListen(bloc, states.stream, initialState: playing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PathWordsBloc>.value(
            value: bloc,
            child: MultiBlocListener(
              listeners: [pathWordsBonusToastListener()],
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    states.add(playing.copyWith(bonusWords: const ['stare']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bonus word: STARE'), findsOneWidget);

    // A reset (fewer bonus words) says nothing.
    states.add(playing.copyWith(bonusWords: const []));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bonus word'), findsNothing);
  });

  testWidgets('a restored run does not announce its bonus words', (
    tester,
  ) async {
    final loading = PathWordsState(day: day);
    final states = StreamController<PathWordsState>();
    addTearDown(states.close);
    final bloc = _MockPathWordsBloc();
    whenListen(bloc, states.stream, initialState: loading);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<PathWordsBloc>.value(
            value: bloc,
            child: MultiBlocListener(
              listeners: [pathWordsBonusToastListener()],
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    states.add(
      PathWordsState(
        day: day,
        puzzle: puzzle,
        status: PathWordsStatus.ready,
        bonusWords: const ['stare'],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Bonus word'), findsNothing);
  });
}
