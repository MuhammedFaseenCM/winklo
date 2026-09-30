import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/path_words/path_words_rules.dart';
import 'package:flutter_test/flutter_test.dart';

PathWordsPuzzle tinyPuzzle() {
  // 2x2: "ab" along row0, "cd" along row1
  return PathWordsPuzzle(
    id: 't',
    day: DateTime(2026, 9, 17),
    size: 2,
    letters: const ['a', 'b', 'c', 'd'],
    targets: [
      PathWordsTarget(
        id: 't0',
        word: 'ab',
        start: const Cell(0, 0),
        path: const [Cell(0, 0), Cell(0, 1)],
        colorIndex: 0,
      ),
      PathWordsTarget(
        id: 't1',
        word: 'cd',
        start: const Cell(1, 0),
        path: const [Cell(1, 0), Cell(1, 1)],
        colorIndex: 1,
      ),
    ],
  );
}

void main() {
  final puzzle = tinyPuzzle();

  test('tryBegin allows any letter cell that is not locked', () {
    expect(
      PathWordsRules.tryBegin(
        puzzle: puzzle,
        cell: const Cell(0, 0),
        locked: {},
        completedTargetIds: {},
      ),
      [const Cell(0, 0)],
    );
    expect(
      PathWordsRules.tryBegin(
        puzzle: puzzle,
        cell: const Cell(0, 1),
        locked: {},
        completedTargetIds: {},
      ),
      [const Cell(0, 1)],
    );
    expect(
      PathWordsRules.tryBegin(
        puzzle: puzzle,
        cell: const Cell(0, 1),
        locked: {const Cell(0, 1)},
        completedTargetIds: {'t0'},
      ),
      isNull,
    );
  });

  test('tryExtend rejects blank unused cells', () {
    final sparse = PathWordsPuzzle(
      id: 'sparse',
      day: DateTime(2026, 9, 17),
      size: 2,
      letters: const ['a', 'b', '', ''],
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
    expect(
      PathWordsRules.tryBegin(
        puzzle: sparse,
        cell: const Cell(1, 0),
        locked: {},
        completedTargetIds: {},
      ),
      isNull,
    );
    expect(
      PathWordsRules.tryExtend(
        puzzle: sparse,
        path: const [Cell(0, 0)],
        candidate: const Cell(1, 0),
        locked: {},
      ),
      isNull,
    );
  });

  test('tryExtend rejects diagonal and locked', () {
    final path = [const Cell(0, 0)];
    expect(
      PathWordsRules.tryExtend(
        puzzle: puzzle,
        path: path,
        candidate: const Cell(1, 1),
        locked: {},
      ),
      isNull,
    );
    expect(
      PathWordsRules.tryExtend(
        puzzle: puzzle,
        path: path,
        candidate: const Cell(0, 1),
        locked: {const Cell(0, 1)},
      ),
      isNull,
    );
  });

  test('completedTarget matches the official path only, not reverse', () {
    expect(
      PathWordsRules.completedTarget(
        puzzle: puzzle,
        path: const [Cell(0, 0), Cell(0, 1)],
        completedTargetIds: {},
      )?.id,
      't0',
    );
    expect(
      PathWordsRules.completedTarget(
        puzzle: puzzle,
        path: const [Cell(0, 1), Cell(0, 0)],
        completedTargetIds: {},
      ),
      isNull,
    );
  });

  test('hintedPath grows connected cells on the unsolved word', () {
    expect(
      PathWordsRules.hintedPath(
        puzzle: puzzle,
        completedTargetIds: {},
        revealedLength: 1,
      ),
      [const Cell(0, 0)],
    );
    expect(
      PathWordsRules.hintedPath(
        puzzle: puzzle,
        completedTargetIds: {},
        revealedLength: 2,
      ),
      [const Cell(0, 0), const Cell(0, 1)],
    );
    expect(
      PathWordsRules.hintedPath(
        puzzle: puzzle,
        completedTargetIds: {},
        revealedLength: 3,
      ),
      [const Cell(0, 0), const Cell(0, 1)],
    );
  });

  test(
    'hintedPath moves to the next word only after the current one is solved',
    () {
      expect(
        PathWordsRules.hintedPath(
          puzzle: puzzle,
          completedTargetIds: {'t0'},
          revealedLength: 1,
        ),
        [const Cell(1, 0)],
      );
      expect(
        PathWordsRules.hintedPath(
          puzzle: puzzle,
          completedTargetIds: {'t0'},
          revealedLength: 2,
        ),
        [const Cell(1, 0), const Cell(1, 1)],
      );
    },
  );

  test('undoActive pops last', () {
    expect(PathWordsRules.undoActive(const [Cell(0, 0), Cell(0, 1)]), [
      const Cell(0, 0),
    ]);
  });

  test('tryExtend rejects cells occupied by a placed stroke', () {
    final locked = PathWordsRules.occupiedCells(const [
      PathWordsStroke(cells: [Cell(0, 0), Cell(0, 1)], colorIndex: 0),
    ]);
    expect(
      PathWordsRules.tryExtend(
        puzzle: puzzle,
        path: const [Cell(1, 1)],
        candidate: const Cell(0, 1),
        locked: locked,
      ),
      isNull,
    );
    expect(
      PathWordsRules.tryBegin(
        puzzle: puzzle,
        cell: const Cell(0, 0),
        locked: locked,
        completedTargetIds: {},
      ),
      isNull,
    );
  });

  test('commitStroke keeps a miss and recolors an exact solution', () {
    final wrong = PathWordsRules.commitStroke(
      puzzle: puzzle,
      cells: const [Cell(0, 0), Cell(1, 0)],
      completedTargetIds: {},
      colorIndex: 3,
    );
    expect(wrong.targetId, isNull);
    expect(wrong.colorIndex, 3);
    expect(wrong.cells, const [Cell(0, 0), Cell(1, 0)]);

    final right = PathWordsRules.commitStroke(
      puzzle: puzzle,
      cells: const [Cell(0, 0), Cell(0, 1)],
      completedTargetIds: {},
      colorIndex: 3,
    );
    expect(right.targetId, 't0');
    expect(right.colorIndex, 0);
  });

  test('nextUnusedColorIndex skips colors already on the board', () {
    final placed = [
      const PathWordsStroke(cells: [Cell(0, 0), Cell(1, 0)], colorIndex: 0),
      const PathWordsStroke(
        cells: [Cell(0, 1), Cell(1, 1)],
        colorIndex: 2,
        targetId: 't0',
      ),
    ];
    expect(
      PathWordsRules.nextUnusedColorIndex(
        puzzle: puzzle,
        completedTargetIds: {'t0'},
        placedPaths: placed,
        paletteLength: 8,
      ),
      1,
    );
  });

  test('truncatePlacedAt keeps the prefix through the tapped cell', () {
    final placed = [
      const PathWordsStroke(
        cells: [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
        colorIndex: 4,
      ),
    ];
    final truncated = PathWordsRules.truncatePlacedAt(
      placedPaths: placed,
      cell: const Cell(0, 1),
    );
    expect(truncated, [
      const PathWordsStroke(cells: [Cell(0, 0), Cell(0, 1)], colorIndex: 4),
    ]);
  });

  test('truncatePlacedAt removes a stroke when only the start remains', () {
    final placed = [
      const PathWordsStroke(
        cells: [Cell(0, 0), Cell(0, 1), Cell(1, 1)],
        colorIndex: 4,
      ),
    ];
    expect(
      PathWordsRules.truncatePlacedAt(
        placedPaths: placed,
        cell: const Cell(0, 0),
      ),
      isEmpty,
    );
  });

  test('truncatePlacedAt ignores correct strokes', () {
    final placed = [
      const PathWordsStroke(
        cells: [Cell(0, 0), Cell(0, 1)],
        colorIndex: 0,
        targetId: 't0',
      ),
    ];
    expect(
      PathWordsRules.truncatePlacedAt(
        placedPaths: placed,
        cell: const Cell(0, 0),
      ),
      isNull,
    );
  });

  test('tryTruncate shortens the active path to the tapped cell', () {
    expect(
      PathWordsRules.tryTruncate(
        path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
        candidate: const Cell(0, 1),
      ),
      [const Cell(0, 0), const Cell(0, 1)],
    );
  });

  test('tryLifoBacktrack pops only when candidate is the previous cell', () {
    final path = [const Cell(0, 0), const Cell(0, 1), const Cell(1, 1)];
    expect(
      PathWordsRules.tryLifoBacktrack(path: path, candidate: const Cell(0, 1)),
      [const Cell(0, 0), const Cell(0, 1)],
    );
    expect(
      PathWordsRules.tryLifoBacktrack(path: path, candidate: const Cell(0, 0)),
      isNull,
    );
    expect(
      PathWordsRules.tryLifoBacktrack(
        path: const [Cell(0, 0)],
        candidate: const Cell(0, 0),
      ),
      isNull,
    );
  });

  test(
    'liveFillTarget fills an empty slot of the drag length, not the official word',
    () {
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

      expect(
        PathWordsRules.liveFillTarget(
          puzzle: puzzle,
          activePath: const [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
          completedTargetIds: {},
        )?.id,
        'cat',
      );
    },
  );

  test(
    'liveFillTarget jumps to the next longer empty slot when the drag grows',
    () {
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

      expect(
        PathWordsRules.liveFillTarget(
          puzzle: puzzle,
          activePath: const [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 0)],
          completedTargetIds: {},
        )?.id,
        'bond',
      );
    },
  );

  test('liveFillTarget skips completed slots', () {
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

    expect(
      PathWordsRules.liveFillTarget(
        puzzle: puzzle,
        activePath: const [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
        completedTargetIds: {'cat'},
      )?.id,
      'bond',
    );
  });

  test('activeTarget matches a word from either end, else the live drag', () {
    expect(
      PathWordsRules.activeTarget(
        puzzle: puzzle,
        activePath: const [Cell(1, 0), Cell(1, 1)],
        completedTargetIds: {},
      )?.id,
      't1',
    );
    expect(
      PathWordsRules.activeTarget(
        puzzle: puzzle,
        activePath: const [Cell(0, 1)],
        completedTargetIds: {},
      )?.id,
      't0',
    );
    expect(
      PathWordsRules.activeTarget(
        puzzle: puzzle,
        activePath: const [Cell(0, 0)],
        completedTargetIds: {'t0'},
      )?.id,
      't1',
    );
  });

  test('looksLikeFailedWordAttempt when length matches but path is wrong', () {
    expect(
      PathWordsRules.looksLikeFailedWordAttempt(
        puzzle: puzzle,
        path: const [Cell(0, 0), Cell(1, 0)],
        completedTargetIds: {},
      ),
      isTrue,
    );
    expect(
      PathWordsRules.looksLikeFailedWordAttempt(
        puzzle: puzzle,
        path: const [Cell(0, 0), Cell(0, 1)],
        completedTargetIds: {},
      ),
      isFalse,
    );
    expect(
      PathWordsRules.looksLikeFailedWordAttempt(
        puzzle: puzzle,
        path: const [Cell(0, 0)],
        completedTargetIds: {},
      ),
      isFalse,
    );
  });

  test(
    'looksLikeFailedWordAttempt waits until the longest remaining word is fully drawn',
    () {
      final mixed = PathWordsPuzzle(
        id: 'mixed',
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
            id: 'cdef',
            word: 'cdef',
            start: Cell(0, 2),
            path: [Cell(0, 2), Cell(1, 0), Cell(1, 1), Cell(1, 2)],
            colorIndex: 1,
          ),
        ],
      );

      // Same length as the short word — do not tip yet (longer word remains).
      expect(
        PathWordsRules.looksLikeFailedWordAttempt(
          puzzle: mixed,
          path: const [Cell(0, 0), Cell(1, 0)],
          completedTargetIds: {},
        ),
        isFalse,
      );

      // Full length of the longest remaining word, but wrong path — tip.
      expect(
        PathWordsRules.looksLikeFailedWordAttempt(
          puzzle: mixed,
          path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1), Cell(1, 0)],
          completedTargetIds: {},
        ),
        isTrue,
      );
    },
  );

  group('listFills', () {
    PathWordsPuzzle mixedLengths() {
      return PathWordsPuzzle(
        id: 'fills',
        day: DateTime(2026, 9, 17),
        size: 3,
        letters: const ['c', 'a', 't', 'b', 'o', 'n', 'd', 'x', 'y'],
        targets: const [
          PathWordsTarget(
            id: 'cat',
            word: 'cat',
            start: Cell(0, 0),
            path: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
            colorIndex: 0,
          ),
          PathWordsTarget(
            id: 'bond',
            word: 'bond',
            start: Cell(1, 0),
            path: [Cell(1, 0), Cell(1, 1), Cell(1, 2), Cell(2, 0)],
            colorIndex: 1,
          ),
          PathWordsTarget(
            id: 'bond2',
            word: 'xy',
            start: Cell(2, 1),
            path: [Cell(2, 1), Cell(2, 2)],
            colorIndex: 2,
          ),
        ],
      );
    }

    test('places a short incorrect stroke into the next longer empty slot', () {
      final puzzle = mixedLengths();
      // 3-letter wrong path while "cat" is already solved → use "bond".
      final fills = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {'cat'},
        placedPaths: const [
          PathWordsStroke(
            cells: [Cell(1, 0), Cell(1, 1), Cell(1, 2)],
            colorIndex: 3,
          ),
        ],
        activePath: const [],
      );

      expect(fills.keys, ['bond']);
      expect(fills['bond']!.letters, ['B', 'O', 'N']);
      expect(fills['bond']!.slotLength, 4);
      expect(fills['bond']!.overflowCount, 0);
      expect(fills['bond']!.colorIndex, 3);
    });

    test('skips a slot whose correct word is already completed', () {
      final puzzle = mixedLengths();
      final fills = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {'bond'},
        placedPaths: const [
          PathWordsStroke(
            cells: [Cell(1, 0), Cell(1, 1), Cell(1, 2)],
            colorIndex: 3,
          ),
        ],
        activePath: const [],
      );

      // Exact 3-letter slot "cat" is free — prefer it over longer.
      expect(fills.keys, ['cat']);
      expect(fills['cat']!.letters, ['B', 'O', 'N']);
    });

    test('reassigns when the previously used slot becomes completed', () {
      final puzzle = mixedLengths();
      final stroke = const PathWordsStroke(
        cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
        colorIndex: 4,
      );

      final before = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {},
        placedPaths: [stroke],
        activePath: const [],
      );
      expect(before.keys, ['cat']);

      final after = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {'cat'},
        placedPaths: [stroke],
        activePath: const [],
      );
      expect(after.keys, ['bond']);
      expect(after['bond']!.letters, ['C', 'A', 'T']);
    });

    test('overflows onto the longest slot when the path is longer', () {
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

      final fills = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {},
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
        activePath: const [],
      );

      expect(fills.keys, ['cde']);
      expect(fills['cde']!.letters, ['A', 'B', 'C', 'D', 'E', 'F']);
      expect(fills['cde']!.slotLength, 3);
      expect(fills['cde']!.overflowCount, 3);
    });

    test('includes the active drag after incorrect placed strokes', () {
      final puzzle = mixedLengths();
      final fills = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {},
        placedPaths: const [
          PathWordsStroke(cells: [Cell(0, 0), Cell(0, 1)], colorIndex: 5),
        ],
        activePath: const [Cell(1, 0), Cell(1, 1), Cell(1, 2)],
      );

      expect(fills['bond2']!.letters, ['C', 'A']);
      expect(fills['cat']!.letters, ['B', 'O', 'N']);
    });

    test('ignores correct placed strokes', () {
      final puzzle = mixedLengths();
      final fills = PathWordsRules.listFills(
        puzzle: puzzle,
        completedTargetIds: {'cat'},
        placedPaths: const [
          PathWordsStroke(
            cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
            colorIndex: 0,
            targetId: 'cat',
          ),
        ],
        activePath: const [],
      );

      expect(fills, isEmpty);
    });
  });
}
