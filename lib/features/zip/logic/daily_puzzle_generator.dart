import 'dart:math';

import '../../../domain/entities/zip_level.dart';
import '../../../domain/play_period.dart';

/// Daily Zip puzzles in the style of popular path-fill games:
/// grids about 6–8, checkpoints from 1 up to at most 15.
class DailyPuzzleGenerator {
  DailyPuzzleGenerator._();

  static const int maxNumbers = 15;
  static const List<int> _gridSizes = [6, 6, 7, 7, 8];

  static String dateId(DateTime date, {Duration period = PlayPeriod.daily}) {
    return 'daily_${PlayPeriod.id(date, period)}';
  }

  static String displayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = DateTime(date.year, date.month, date.day);
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  static int seedFor(DateTime date, {Duration period = PlayPeriod.daily}) {
    final local = PlayPeriod.bucket(date, period);
    final daySeed = local.year * 10000 + local.month * 100 + local.day;
    if (!PlayPeriod.isSubDaily(period)) return daySeed;
    return daySeed * 10000 + local.hour * 100 + local.minute;
  }

  static final Map<String, ZipLevel Function(String id, int seed)>
  _curatedOverrides = {
    'daily_20260929': (id, seed) => ZipLevel(
      id: id,
      size: 6,
      numbers: {
        Cell(5, 5): 1,
        Cell(4, 3): 2,
        Cell(2, 2): 3,
        Cell(0, 5): 4,
        Cell(0, 0): 5,
        Cell(5, 0): 6,
      },
      walls: const [Wall(Cell(5, 0), Cell(5, 1)), Wall(Cell(1, 4), Cell(1, 5))],
      order: seed,
      solution: const [
        Cell(5, 5),
        Cell(5, 4),
        Cell(5, 3),
        Cell(5, 2),
        Cell(5, 1),
        Cell(4, 1),
        Cell(4, 2),
        Cell(4, 3),
        Cell(4, 4),
        Cell(4, 5),
        Cell(3, 5),
        Cell(3, 4),
        Cell(3, 3),
        Cell(3, 2),
        Cell(2, 2),
        Cell(2, 3),
        Cell(1, 3),
        Cell(1, 4),
        Cell(2, 4),
        Cell(2, 5),
        Cell(1, 5),
        Cell(0, 5),
        Cell(0, 4),
        Cell(0, 3),
        Cell(0, 2),
        Cell(1, 2),
        Cell(1, 1),
        Cell(0, 1),
        Cell(0, 0),
        Cell(1, 0),
        Cell(2, 0),
        Cell(2, 1),
        Cell(3, 1),
        Cell(3, 0),
        Cell(4, 0),
        Cell(5, 0),
      ],
    ),
  };

  /// Same play period → same puzzle for every player.
  static ZipLevel forDate(DateTime date, {Duration period = PlayPeriod.daily}) {
    final id = dateId(date, period: period);
    final seed = seedFor(date, period: period);
    final overrideBuilder = _curatedOverrides[id];
    if (overrideBuilder != null) {
      return overrideBuilder(id, seed);
    }

    final rng = Random(seed);
    final size = _gridSizes[seed % _gridSizes.length];
    final path = _twistyHamiltonian(size, rng);
    final numberCount = _numberCountFor(size, rng);
    final numbers = _placeNumbers(path, numberCount);
    final walls = _placeWalls(size, path, rng);

    return ZipLevel(
      id: id,
      size: size,
      numbers: numbers,
      walls: walls,
      order: seed,
      solution: path,
    );
  }

  static ZipLevel today([DateTime? now, Duration period = PlayPeriod.daily]) =>
      forDate(now ?? DateTime.now(), period: period);

  static int _numberCountFor(int size, Random rng) {
    final cells = size * size;
    final minCount = size <= 6 ? 6 : 8;
    final maxCount = min(maxNumbers, cells);
    final lo = min(minCount, maxCount);
    return lo + rng.nextInt(maxCount - lo + 1);
  }

  static List<Cell> _twistyHamiltonian(int size, Random rng) {
    var path = _orientedSerpentine(size, rng);
    final mutations = size * size * 8;
    for (var i = 0; i < mutations; i++) {
      final next = _tryBackbite(path, size, rng);
      if (next != null) path = next;
      if (rng.nextInt(4) == 0) {
        path = path.reversed.toList();
      }
      if (_longestStraightRun(path) < size) {
        // Keep mutating a bit after the first kink so the snake is not almost-straight.
        if (i > size * size) return path;
      }
    }
    if (_longestStraightRun(path) < size) return path;

    for (var i = 0; i < mutations; i++) {
      final next = _tryBackbite(path, size, rng);
      if (next != null) path = next;
      path = path.reversed.toList();
      if (_longestStraightRun(path) < size) return path;
    }
    return path;
  }

  static List<Cell>? _tryBackbite(List<Cell> path, int size, Random rng) {
    final end = path.last;
    final indexByCell = <Cell, int>{
      for (var i = 0; i < path.length; i++) path[i]: i,
    };
    final pivots = <int>[];
    for (final neighbor in _neighbors(end, size)) {
      final index = indexByCell[neighbor];
      if (index == null || index >= path.length - 2) continue;
      pivots.add(index);
    }
    if (pivots.isEmpty) return null;
    final pivot = pivots[rng.nextInt(pivots.length)];
    return [...path.sublist(0, pivot + 1), ...path.sublist(pivot + 1).reversed];
  }

  static List<Cell> _neighbors(Cell cell, int size) {
    return [
      if (cell.row > 0) Cell(cell.row - 1, cell.col),
      if (cell.row + 1 < size) Cell(cell.row + 1, cell.col),
      if (cell.col > 0) Cell(cell.row, cell.col - 1),
      if (cell.col + 1 < size) Cell(cell.row, cell.col + 1),
    ];
  }

  static int _longestStraightRun(List<Cell> path) {
    if (path.length < 2) return path.length;
    var best = 1;
    var run = 1;
    var previousDr = path[1].row - path[0].row;
    var previousDc = path[1].col - path[0].col;
    for (var i = 1; i < path.length; i++) {
      final dr = path[i].row - path[i - 1].row;
      final dc = path[i].col - path[i - 1].col;
      if (dr == previousDr && dc == previousDc) {
        run++;
      } else {
        previousDr = dr;
        previousDc = dc;
        run = 2;
      }
      if (run > best) best = run;
    }
    return best;
  }

  static List<Cell> _orientedSerpentine(int size, Random rng) {
    var path = _serpentine(size);

    // Apply geometric transforms that preserve adjacency along the path.
    for (var i = 0; i < rng.nextInt(4); i++) {
      path = _rotate90(path, size);
    }
    if (rng.nextBool()) {
      path = path.map((c) => Cell(c.row, size - 1 - c.col)).toList();
    }
    if (rng.nextBool()) {
      path = path.reversed.toList();
    }
    return path;
  }

  static List<Cell> _serpentine(int size) {
    final path = <Cell>[];
    for (var r = 0; r < size; r++) {
      if (r.isEven) {
        for (var c = 0; c < size; c++) {
          path.add(Cell(r, c));
        }
      } else {
        for (var c = size - 1; c >= 0; c--) {
          path.add(Cell(r, c));
        }
      }
    }
    return path;
  }

  static List<Cell> _rotate90(List<Cell> path, int size) {
    return path.map((c) => Cell(c.col, size - 1 - c.row)).toList();
  }

  static Map<Cell, int> _placeNumbers(List<Cell> path, int count) {
    final numbers = <Cell, int>{};
    final span = path.length - 1;
    for (var n = 1; n <= count; n++) {
      final index = count == 1 ? 0 : ((span * (n - 1)) / (count - 1)).round();
      numbers[path[index]] = n;
    }
    return numbers;
  }

  static List<Wall> _placeWalls(int size, List<Cell> path, Random rng) {
    final onPath = <String>{};
    for (var i = 0; i < path.length - 1; i++) {
      onPath.add(_edgeKey(path[i], path[i + 1]));
    }

    final candidates = <Wall>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final a = Cell(r, c);
        if (c + 1 < size) {
          final b = Cell(r, c + 1);
          if (!onPath.contains(_edgeKey(a, b))) {
            candidates.add(Wall(a, b));
          }
        }
        if (r + 1 < size) {
          final b = Cell(r + 1, c);
          if (!onPath.contains(_edgeKey(a, b))) {
            candidates.add(Wall(a, b));
          }
        }
      }
    }

    candidates.shuffle(rng);
    final wallCount = min(candidates.length, 2 + rng.nextInt(size));
    return candidates.take(wallCount).toList();
  }

  static String _edgeKey(Cell a, Cell b) {
    final first = a.row < b.row || (a.row == b.row && a.col <= b.col) ? a : b;
    final second = first == a ? b : a;
    return '${first.row},${first.col}|${second.row},${second.col}';
  }
}
