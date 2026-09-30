import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_word_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PathWordsPuzzle _puzzle() {
  return PathWordsPuzzle(
    id: 't',
    day: DateTime(2026, 9, 17),
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
      PathWordsTarget(
        id: 't1',
        word: 'cd',
        start: Cell(1, 0),
        path: [Cell(1, 0), Cell(1, 1)],
        colorIndex: 1,
      ),
    ],
  );
}

void main() {
  testWidgets('keeps unfound words blank and checks only completed ones', (
    tester,
  ) async {
    final puzzle = _puzzle();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PathWordsWordList(
            puzzle: puzzle,
            activePath: const [],
            placedPaths: const [],
            completedTargetIds: const {'t0'},
            palette: const [Colors.red, Colors.blue],
          ),
        ),
      ),
    );

    final found = find.byKey(const Key('pathWordsWord_t0'));
    final unfound = find.byKey(const Key('pathWordsWord_t1'));

    expect(
      find.descendant(of: found, matching: find.text('A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: found, matching: find.text('B')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pathWordsCheck_t0')), findsOneWidget);

    expect(
      find.descendant(of: unfound, matching: find.text('C')),
      findsNothing,
    );
    expect(
      find.descendant(of: unfound, matching: find.text('D')),
      findsNothing,
    );
    expect(find.byKey(const Key('pathWordsCheck_t1')), findsNothing);
    expect(find.text('AB'), findsNothing);
    expect(find.text('CD'), findsNothing);
  });

  testWidgets('fills an empty slot of the drag length, not the official word', (
    tester,
  ) async {
    final puzzle = PathWordsPuzzle(
      id: 'decoy',
      day: DateTime(2026, 9, 17),
      size: 3,
      letters: const ['b', 'o', 'n', 'd', 'c', 'a', 't', 'x', 'y'],
      targets: const [
        PathWordsTarget(
          id: 'bond',
          word: 'bond',
          start: Cell(0, 0),
          path: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 0)],
          colorIndex: 0,
        ),
        PathWordsTarget(
          id: 'cat',
          word: 'cat',
          start: Cell(1, 1),
          path: [Cell(1, 1), Cell(1, 2), Cell(2, 0)],
          colorIndex: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PathWordsWordList(
            puzzle: puzzle,
            activePath: const [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
            placedPaths: const [],
            completedTargetIds: const {},
            palette: const [Colors.red, Colors.blue],
          ),
        ),
      ),
    );

    final decoy = find.byKey(const Key('pathWordsWord_cat'));
    final official = find.byKey(const Key('pathWordsWord_bond'));

    expect(
      find.descendant(of: decoy, matching: find.text('B')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: decoy, matching: find.text('O')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: decoy, matching: find.text('N')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: official, matching: find.text('B')),
      findsNothing,
    );
    expect(find.byKey(const Key('pathWordsCheck_cat')), findsNothing);
  });

  testWidgets('shows incorrect placed strokes in a suitable empty slot', (
    tester,
  ) async {
    final puzzle = PathWordsPuzzle(
      id: 'wrong',
      day: DateTime(2026, 9, 17),
      size: 3,
      letters: const ['b', 'o', 'n', 'd', 'c', 'a', 't', 'x', 'y'],
      targets: const [
        PathWordsTarget(
          id: 'bond',
          word: 'bond',
          start: Cell(0, 0),
          path: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 0)],
          colorIndex: 0,
        ),
        PathWordsTarget(
          id: 'cat',
          word: 'cat',
          start: Cell(1, 1),
          path: [Cell(1, 1), Cell(1, 2), Cell(2, 0)],
          colorIndex: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PathWordsWordList(
            puzzle: puzzle,
            activePath: const [],
            placedPaths: const [
              PathWordsStroke(
                cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
                colorIndex: 2,
              ),
            ],
            completedTargetIds: const {'cat'},
            palette: const [Colors.red, Colors.blue, Colors.green],
          ),
        ),
      ),
    );

    final bond = find.byKey(const Key('pathWordsWord_bond'));
    expect(find.descendant(of: bond, matching: find.text('B')), findsOneWidget);
    expect(find.descendant(of: bond, matching: find.text('O')), findsOneWidget);
    expect(find.descendant(of: bond, matching: find.text('N')), findsOneWidget);
    expect(find.byKey(const Key('pathWordsCheck_bond')), findsNothing);
  });

  testWidgets('shows overflow letters with a crossed extra cell', (
    tester,
  ) async {
    final puzzle = PathWordsPuzzle(
      id: 'overflow',
      day: DateTime(2026, 9, 17),
      size: 3,
      letters: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      targets: const [
        PathWordsTarget(
          id: 'ab',
          word: 'ab',
          start: Cell(0, 0),
          path: [Cell(0, 0), Cell(0, 1)],
          colorIndex: 0,
        ),
        PathWordsTarget(
          id: 'cde',
          word: 'cde',
          start: Cell(0, 2),
          path: [Cell(0, 2), Cell(1, 0), Cell(1, 1)],
          colorIndex: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PathWordsWordList(
            puzzle: puzzle,
            activePath: const [],
            placedPaths: const [
              PathWordsStroke(
                cells: [
                  Cell(0, 0),
                  Cell(0, 1),
                  Cell(0, 2),
                  Cell(1, 0),
                  Cell(1, 1),
                  Cell(1, 2),
                ],
                colorIndex: 2,
              ),
            ],
            completedTargetIds: const {},
            palette: const [Colors.red, Colors.blue, Colors.green],
          ),
        ),
      ),
    );

    final long = find.byKey(const Key('pathWordsWord_cde'));
    expect(find.descendant(of: long, matching: find.text('A')), findsOneWidget);
    expect(find.descendant(of: long, matching: find.text('B')), findsOneWidget);
    expect(find.descendant(of: long, matching: find.text('C')), findsOneWidget);
    expect(find.byKey(const Key('pathWordsOverflow_cde_0')), findsOneWidget);
    expect(find.byKey(const Key('pathWordsOverflow_cde_1')), findsOneWidget);
    expect(find.byKey(const Key('pathWordsOverflow_cde_2')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('pathWordsOverflow_cde_0')),
        matching: find.text('D'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows word slots in ascending length order', (tester) async {
    final puzzle = PathWordsPuzzle(
      id: 'order',
      day: DateTime(2026, 9, 17),
      size: 3,
      letters: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      targets: const [
        PathWordsTarget(
          id: 'long',
          word: 'abcd',
          start: Cell(0, 0),
          path: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 0)],
          colorIndex: 0,
        ),
        PathWordsTarget(
          id: 'short',
          word: 'ef',
          start: Cell(1, 1),
          path: [Cell(1, 1), Cell(1, 2)],
          colorIndex: 1,
        ),
        PathWordsTarget(
          id: 'mid',
          word: 'ghi',
          start: Cell(2, 0),
          path: [Cell(2, 0), Cell(2, 1), Cell(2, 2)],
          colorIndex: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PathWordsWordList(
            puzzle: puzzle,
            activePath: const [],
            placedPaths: const [],
            completedTargetIds: const {},
            palette: const [Colors.red, Colors.blue, Colors.green],
          ),
        ),
      ),
    );

    final short = tester.getTopLeft(
      find.byKey(const Key('pathWordsWord_short')),
    );
    final mid = tester.getTopLeft(find.byKey(const Key('pathWordsWord_mid')));
    final long = tester.getTopLeft(find.byKey(const Key('pathWordsWord_long')));

    expect(short.dy, lessThan(mid.dy));
    expect(mid.dy, lessThan(long.dy));
    expect(short.dx, mid.dx);
    expect(mid.dx, long.dx);
  });
}
