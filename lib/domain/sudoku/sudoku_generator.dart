import 'dart:math';

import '../entities/sudoku_difficulty.dart';
import '../entities/sudoku_puzzle.dart';
import '../play_period.dart';
import '../streak_calculator.dart';
import '../stable_seed.dart';

/// Seeded daily 6×6 Sudoku generator (boxes 2×3).
abstract final class SudokuGenerator {
  SudokuGenerator._();

  static const generatorVersion = 1;
  static const size = 6;
  static const boxRows = 2;
  static const boxCols = 3;
  static const cellCount = size * size;

  /// Known-valid full grid used when random dig fails.
  static const List<int> cannedSolution = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    4,
    5,
    6,
    1,
    2,
    3,
    2,
    3,
    1,
    5,
    6,
    4,
    5,
    6,
    4,
    2,
    3,
    1,
    3,
    1,
    2,
    6,
    4,
    5,
    6,
    4,
    5,
    3,
    1,
    2,
  ];

  static SudokuDifficulty difficultyForDate(DateTime day) {
    final local = DateTime(day.year, day.month, day.day);
    final ordinal = local.difference(DateTime(local.year)).inDays;
    switch (ordinal % 3) {
      case 0:
        return SudokuDifficulty.easy;
      case 1:
        return SudokuDifficulty.medium;
      default:
        return SudokuDifficulty.hard;
    }
  }

  static ({int min, int max}) clueBand(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return (min: 22, max: 26);
      case SudokuDifficulty.medium:
        return (min: 16, max: 21);
      case SudokuDifficulty.hard:
        return (min: 12, max: 15);
    }
  }

  static SudokuPuzzle generate({
    required DateTime day,
    Duration period = PlayPeriod.daily,
  }) {
    final bucket = PlayPeriod.bucket(day, period);
    final dateId = PlayPeriod.id(bucket, period);
    final seed = stableSeed('$dateId:$generatorVersion');
    final rng = Random(seed);
    final difficulty = difficultyForDate(bucket);
    final band = clueBand(difficulty);
    final targetClues = band.min + rng.nextInt(band.max - band.min + 1);

    for (var attempt = 0; attempt < 8; attempt++) {
      final full = _randomFullGrid(Random(seed + attempt * 997));
      final given = _digClues(
        full: full,
        targetClues: targetClues,
        rng: Random(seed + attempt * 991 + 13),
      );
      if (given != null) {
        return SudokuPuzzle(
          id: 'sudoku_$dateId',
          dateId: dateId,
          given: given,
          solution: full,
          difficulty: difficulty,
        );
      }
    }

    // Deterministic fallback: transform canned + dig with seed index.
    final full = _transformCanned(Random(seed));
    final given =
        _digClues(
          full: full,
          targetClues: targetClues,
          rng: Random(seed ^ 0x5ed0),
          force: true,
        ) ??
        _forceClueCount(full, targetClues, Random(seed ^ 0xabcd));

    return SudokuPuzzle(
      id: 'sudoku_$dateId',
      dateId: dateId,
      given: given,
      solution: full,
      difficulty: difficulty,
    );
  }

  /// Calendar day id helper for tests / callers that use streak ids.
  static String calendarDateId(DateTime day) => StreakCalculator.dateId(day);

  static List<int> _randomFullGrid(Random rng) {
    final grid = List<int>.filled(cellCount, 0);
    final ok = _fill(grid, 0, rng);
    if (ok) return grid;
    return _transformCanned(rng);
  }

  static List<int> _transformCanned(Random rng) {
    final digits = List<int>.generate(size, (i) => i + 1)..shuffle(rng);
    return [for (final v in cannedSolution) digits[v - 1]];
  }

  static bool _fill(List<int> grid, int index, Random rng) {
    if (index >= cellCount) return true;
    if (grid[index] != 0) return _fill(grid, index + 1, rng);

    final candidates = List<int>.generate(size, (i) => i + 1)..shuffle(rng);
    for (final digit in candidates) {
      if (_canPlace(grid, index, digit)) {
        grid[index] = digit;
        if (_fill(grid, index + 1, rng)) return true;
        grid[index] = 0;
      }
    }
    return false;
  }

  static List<int>? _digClues({
    required List<int> full,
    required int targetClues,
    required Random rng,
    bool force = false,
  }) {
    final given = List<int>.from(full);
    final order = List<int>.generate(cellCount, (i) => i)..shuffle(rng);
    var clues = cellCount;

    for (final index in order) {
      if (clues <= targetClues) break;
      final saved = given[index];
      given[index] = 0;
      if (_countSolutions(given, limit: 2) != 1) {
        given[index] = saved;
        if (!force) {
          // Keep trying other cells; uniqueness required.
        }
      } else {
        clues--;
      }
    }

    if (clues > targetClues && !force) {
      // Could not dig enough while unique — fail so caller retries.
      if (clues > clueBand(SudokuDifficulty.easy).max) return null;
    }

    // Accept if within any reasonable band or forced.
    if (force || clues <= clueBand(SudokuDifficulty.easy).max) {
      return given;
    }
    return null;
  }

  static List<int> _forceClueCount(
    List<int> full,
    int targetClues,
    Random rng,
  ) {
    final given = List<int>.from(full);
    final order = List<int>.generate(cellCount, (i) => i)..shuffle(rng);
    var clues = cellCount;
    for (final index in order) {
      if (clues <= targetClues) break;
      given[index] = 0;
      clues--;
    }
    // Restore uniqueness by filling back if needed.
    if (_countSolutions(given, limit: 2) != 1) {
      return List<int>.from(full); // all clues — still playable
    }
    return given;
  }

  static int _countSolutions(List<int> given, {required int limit}) {
    final grid = List<int>.from(given);
    var count = 0;

    bool search(int index) {
      if (count >= limit) return true;
      if (index >= cellCount) {
        count++;
        return count >= limit;
      }
      if (grid[index] != 0) return search(index + 1);

      for (var digit = 1; digit <= size; digit++) {
        if (_canPlace(grid, index, digit)) {
          grid[index] = digit;
          if (search(index + 1)) {
            grid[index] = 0;
            return true;
          }
          grid[index] = 0;
        }
      }
      return false;
    }

    search(0);
    return count;
  }

  static bool _canPlace(List<int> grid, int index, int digit) {
    final row = index ~/ size;
    final col = index % size;

    for (var c = 0; c < size; c++) {
      if (grid[row * size + c] == digit) return false;
    }
    for (var r = 0; r < size; r++) {
      if (grid[r * size + col] == digit) return false;
    }

    final boxRow = (row ~/ boxRows) * boxRows;
    final boxCol = (col ~/ boxCols) * boxCols;
    for (var r = boxRow; r < boxRow + boxRows; r++) {
      for (var c = boxCol; c < boxCol + boxCols; c++) {
        if (grid[r * size + c] == digit) return false;
      }
    }
    return true;
  }

  /// Exposed for tests: solution count for a given board.
  static int solutionCount(List<int> given, {int limit = 2}) =>
      _countSolutions(given, limit: limit);
}
