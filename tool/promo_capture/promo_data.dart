import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/path_words_puzzle.dart';
import 'package:winklo/domain/entities/zip_level.dart';
import 'package:winklo/domain/game_ids.dart';

/// The boards, players and results the promo shows. The names are invented;
/// no real player appears. Zip is the Instagram carousel's board (8×8, seven
/// numbers, 18 walls, one solution), so the campaign shows one puzzle.

const promoUid = 'me';
const promoName = 'Anu';

List<Cell> _cells(List<List<int>> rc) => [for (final [r, c] in rc) Cell(r, c)];

/// The solution, from the 1 on the left edge to the 7 on the right.
final zipPath = _cells(const [
  [3, 0], [2, 0], [1, 0], [0, 0], [0, 1], [1, 1], [1, 2], [0, 2], //
  [0, 3], [1, 3], [2, 3], [2, 2], [2, 1], [3, 1], [3, 2], [3, 3],
  [3, 4], [4, 4], [4, 3], [4, 2], [4, 1], [4, 0], [5, 0], [5, 1],
  [5, 2], [6, 2], [6, 1], [6, 0], [7, 0], [7, 1], [7, 2], [7, 3],
  [6, 3], [5, 3], [5, 4], [5, 5], [6, 5], [6, 4], [7, 4], [7, 5],
  [7, 6], [7, 7], [6, 7], [6, 6], [5, 6], [5, 7], [4, 7], [3, 7],
  [2, 7], [2, 6], [3, 6], [4, 6], [4, 5], [3, 5], [2, 5], [2, 4],
  [1, 4], [0, 4], [0, 5], [1, 5], [1, 6], [0, 6], [0, 7], [1, 7],
]);

ZipLevel promoZipLevel(DateTime day) {
  const nums = [
    [3, 0, 1], [2, 2, 2], [4, 0, 3], [6, 3, 4], [6, 7, 5], [3, 5, 6], //
    [1, 7, 7],
  ];
  const walls = [
    [
      [5, 4],
      [6, 4],
    ],
    [
      [2, 2],
      [3, 2],
    ],
    [
      [1, 2],
      [1, 3],
    ],
    [
      [5, 1],
      [6, 1],
    ], //
    [
      [2, 4],
      [3, 4],
    ],
    [
      [3, 4],
      [3, 5],
    ],
    [
      [4, 1],
      [5, 1],
    ],
    [
      [5, 2],
      [5, 3],
    ],
    [
      [1, 1],
      [2, 1],
    ],
    [
      [3, 5],
      [3, 6],
    ],
    [
      [3, 3],
      [4, 3],
    ],
    [
      [4, 4],
      [5, 4],
    ],
    [
      [4, 4],
      [4, 5],
    ],
    [
      [1, 7],
      [2, 7],
    ],
    [
      [0, 1],
      [0, 2],
    ],
    [
      [5, 7],
      [6, 7],
    ],
    [
      [2, 3],
      [3, 3],
    ],
    [
      [7, 3],
      [7, 4],
    ],
  ];
  return ZipLevel(
    // Daily levels are the Firestore doc `daily_YYYYMMDD`; Home keys Zip by it.
    id:
        'daily_${day.year}${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}',
    size: 8,
    numbers: {for (final [r, c, n] in nums) Cell(r, c): n},
    walls: [
      for (final [a, b] in walls) Wall(Cell(a[0], a[1]), Cell(b[0], b[1])),
    ],
    solution: zipPath,
  );
}

/// "Built for speed", the Path Words hype spot's board. Words in the order
/// the promo traces them.
const pathWordsRows = [
  ['', 'W', 'A', 'L', 'C', ''],
  ['R', 'O', 'F', '', 'O', 'N'],
  ['R', 'A', 'T', 'E', 'E', ''],
  ['R', '', 'A', 'T', 'H', 'C'],
  ['O', 'C', 'H', 'E', 'M', ''],
  ['', 'K', 'E', 'T', 'O', 'C'],
];

final pathWordsTraces = <(String, int, List<Cell>)>[
  (
    'arrow',
    3,
    _cells(const [
      [2, 1],
      [2, 0],
      [1, 0],
      [1, 1],
      [0, 1],
    ]),
  ),
  (
    'comet',
    1,
    _cells(const [
      [5, 5],
      [5, 4],
      [4, 4],
      [4, 3],
      [3, 3],
    ]),
  ),
  (
    'rocket',
    0,
    _cells(const [
      [3, 0],
      [4, 0],
      [4, 1],
      [5, 1],
      [5, 2],
      [5, 3],
    ]),
  ),
  (
    'falcon',
    4,
    _cells(const [
      [1, 2],
      [0, 2],
      [0, 3],
      [0, 4],
      [1, 4],
      [1, 5],
    ]),
  ),
  (
    'cheetah',
    2,
    _cells(const [
      [3, 5],
      [3, 4],
      [2, 4],
      [2, 3],
      [2, 2],
      [3, 2],
      [4, 2],
    ]),
  ),
];

PathWordsPuzzle promoPathWords(DateTime day) => PathWordsPuzzle(
  id: 'promo_pw',
  day: day,
  size: 6,
  letters: [
    for (final row in pathWordsRows)
      for (final l in row) l.toLowerCase(),
  ],
  targets: [
    for (final (i, (word, color, path)) in pathWordsTraces.indexed)
      PathWordsTarget(
        id: 't$i',
        word: word,
        start: path.first,
        path: path,
        colorIndex: color,
      ),
  ],
  theme: 'Built for speed',
  definitions: const {
    'arrow': 'A pointed stick shot from a bow.',
    'comet': 'An icy body that grows a glowing tail near the Sun.',
    'rocket': 'A vehicle pushed upward by burning fuel.',
    'falcon': 'A swift bird of prey with long, pointed wings.',
    'cheetah': 'The fastest land animal, a spotted big cat.',
  },
);

/// One board per game. The player is #4 on Zip at 0:48 (as in the carousel).
const _players = [
  ('Maya R', 'preset_08'),
  ('Arjun S', 'preset_09'),
  ('Leo T', 'preset_05'),
  (promoName, 'preset_01'),
  ('Aisha K', 'preset_06'),
  ('Rahul M', 'preset_04'),
  ('Sara J', 'preset_10'),
  ('Kiran B', 'preset_11'),
  ('Neha P', 'preset_03'),
  ('Omar D', 'preset_07'),
  ('Priya N', 'preset_12'),
  ('Joel M', 'preset_02'),
];

List<LeaderboardEntry> promoBoard(String gameId) {
  final (order, times) = switch (gameId) {
    GameIds.pathWords => (
      [2, 0, 3, 1, 5, 4, 7, 6, 9, 8, 11, 10],
      [64, 71, 75, 79, 86, 90, 97, 104, 111, 118, 126, 133],
    ),
    GameIds.sudoku => (
      [1, 3, 0, 2, 4, 6, 5, 8, 7, 10, 9, 11],
      [212, 228, 236, 247, 259, 268, 281, 293, 305, 318, 332, 347],
    ),
    _ => (
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      [41, 44, 46, 48, 52, 55, 59, 63, 68, 74, 81, 88],
    ),
  };
  return [
    for (var i = 0; i < order.length; i++)
      LeaderboardEntry(
        uid: _players[order[i]].$1 == promoName ? promoUid : 'p${order[i]}',
        displayName: _players[order[i]].$1,
        avatarId: _players[order[i]].$2,
        timeSeconds: times[i],
        updatedAt: DateTime.utc(2026, 10, 21),
        rank: i + 1,
        usedHints: i % 3 == 2 ? null : false,
        hadMistakes: gameId == GameIds.sudoku && i < 4 ? false : null,
        currentStreak: [7, 12, 5, 7, 9, 3, 21, 4, 6, 2, 8, 3][order[i]],
      ),
  ];
}
