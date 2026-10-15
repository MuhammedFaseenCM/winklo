import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/domain/entities/leaderboard_proof.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';

void main() {
  test('proofs serialise as the Worker reads them', () {
    expect(const ZipLeaderboardProof([Cell(0, 0), Cell(0, 1)]).toJson(), {
      'path': [
        [0, 0],
        [0, 1],
      ],
    });
    expect(const SudokuLeaderboardProof([1, 2, 3]).toJson(), {
      'grid': [1, 2, 3],
    });
    expect(
      const PathWordsLeaderboardProof([
        PathWordsProofStroke(targetId: 't1', cells: [Cell(1, 2)]),
      ]).toJson(),
      {
        'strokes': [
          {
            'targetId': 't1',
            'cells': [
              [1, 2],
            ],
          },
        ],
      },
    );
  });

  test('a Zip proof rebuilds from a saved board', () {
    expect(ZipLeaderboardProof.fromBoard('0,0;0,1;1,1')?.path, const [
      Cell(0, 0),
      Cell(0, 1),
      Cell(1, 1),
    ]);
    for (final bad in [null, '', '0,0;x', '0;1', '-1,0']) {
      expect(ZipLeaderboardProof.fromBoard(bad), isNull, reason: bad);
    }
  });

  test('a Path Words proof uses the traced strokes, or the stored route', () {
    final puzzle = PathWordsPuzzle(
      id: 'p',
      day: DateTime(2026, 10, 15),
      size: 2,
      letters: const ['a', 't', 't', 'o'],
      targets: const [
        PathWordsTarget(
          id: 'w1',
          word: 'at',
          start: Cell(0, 0),
          path: [Cell(0, 0), Cell(0, 1)],
          colorIndex: 0,
        ),
        PathWordsTarget(
          id: 'w2',
          word: 'to',
          start: Cell(1, 0),
          path: [Cell(1, 0), Cell(1, 1)],
          colorIndex: 1,
        ),
      ],
    );

    final proof = PathWordsLeaderboardProof.fromRun(
      puzzle: puzzle,
      completedTargetIds: {'w1', 'w2'},
      placedPaths: const [
        PathWordsStroke(
          cells: [Cell(0, 0), Cell(1, 0)],
          colorIndex: 0,
          targetId: 'w1',
        ),
        PathWordsStroke(cells: [Cell(0, 1)], colorIndex: 3),
      ],
    );

    expect(proof.toJson(), {
      'strokes': [
        {
          'targetId': 'w1',
          'cells': [
            [0, 0],
            [1, 0],
          ],
        },
        {
          'targetId': 'w2',
          'cells': [
            [1, 0],
            [1, 1],
          ],
        },
      ],
    });
  });
}
