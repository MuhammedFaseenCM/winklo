import 'dart:math';

import '../entities/cell.dart';
import '../entities/path_words_puzzle.dart';
import '../play_period.dart';
import '../stable_seed.dart';

abstract final class PathWordsGenerator {
  static const generatorVersion = 6;

  static const int _minSize = 3;
  static const int _maxSize = 6;
  static const int _minWordLen = 3;
  static const int _maxWordLen = 5;

  static PathWordsPuzzle generate({
    required DateTime day,
    required List<String> words,
    Duration period = PlayPeriod.daily,
  }) {
    final local = day.toLocal();
    final bucket = PlayPeriod.bucket(local, period);
    final dateId = PlayPeriod.id(bucket, period);
    final localDay = DateTime(bucket.year, bucket.month, bucket.day);
    final seed = stableSeed('$dateId:$generatorVersion');
    final rng = Random(seed);

    final normalizedWords =
        words
            .map((w) => w.trim().toLowerCase())
            .where((w) => w.isNotEmpty)
            .where((w) => RegExp(r'^[a-z]+$').hasMatch(w))
            .where((w) => w.length >= _minWordLen && w.length <= _maxWordLen)
            .toSet()
            .toList()
          ..sort();

    final buckets = <int, List<String>>{};
    for (final word in normalizedWords) {
      (buckets[word.length] ??= <String>[]).add(word);
    }

    const maxAttempts = 120;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final wordCount = _pickWordCount(rng);
      final composition = _pickComposition(rng, wordCount, buckets);
      if (composition == null) continue;

      final baseSize = _gridSizeFor(composition);
      final maxTrySize = baseSize + 1 > _maxSize ? _maxSize : baseSize + 1;
      for (var size = baseSize; size <= maxTrySize; size++) {
        final puzzle = _tryPack(
          rng: rng,
          day: localDay,
          dateId: dateId,
          buckets: buckets,
          composition: composition,
          size: size,
        );
        if (puzzle != null) {
          return puzzle;
        }
      }
    }

    throw StateError('PathWordsGenerator failed for $dateId');
  }

  static PathWordsPuzzle? _tryPack({
    required Random rng,
    required DateTime day,
    required String dateId,
    required Map<int, List<String>> buckets,
    required List<int> composition,
    required int size,
  }) {
    final lengths = [...composition]..sort((a, b) => b.compareTo(a));

    final availableByLength = <int, List<String>>{};
    final chosenWords = <String>[];
    for (final len in lengths) {
      final pool = (availableByLength[len] ??= [...?buckets[len]]
        ..shuffle(rng));
      if (pool.isEmpty) return null;
      chosenWords.add(pool.removeLast());
    }

    final occupied = <Cell>{};
    final letters = List<String?>.filled(size * size, null);
    final targets = <PathWordsTarget>[];

    for (var i = 0; i < chosenWords.length; i++) {
      final word = chosenWords[i];
      final path = _placeTwistyPath(
        rng: rng,
        length: word.length,
        occupied: occupied,
        size: size,
      );
      if (path == null) return null;

      occupied.addAll(path);
      for (var j = 0; j < path.length; j++) {
        final cell = path[j];
        letters[cell.row * size + cell.col] = word[j];
      }

      targets.add(
        PathWordsTarget(
          id: 'path_words_${dateId}_$i',
          word: word,
          start: path.first,
          path: path,
          colorIndex: i,
        ),
      );
    }

    return _trimEmptySquareBorders(
      PathWordsPuzzle(
        id: 'path_words_$dateId',
        day: day,
        size: size,
        letters: [for (final letter in letters) letter ?? ''],
        targets: targets,
      ),
    );
  }

  static int _gridSizeFor(List<int> composition) {
    final letterCount = composition.fold<int>(0, (sum, n) => sum + n);
    var size = _minSize;
    while (size * size < letterCount && size < _maxSize) {
      size++;
    }
    return size;
  }

  static int _pickWordCount(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.08) return 6;
    if (roll < 0.30) return 5;
    if (roll < 0.70) return 4;
    return 3;
  }

  static List<int>? _pickComposition(
    Random rng,
    int wordCount,
    Map<int, List<String>> buckets,
  ) {
    final composition = <int>[];
    final used = <int, int>{};
    for (var i = 0; i < wordCount; i++) {
      final len = _pickLength(rng, buckets, used);
      if (len == null) return null;
      composition.add(len);
      used[len] = (used[len] ?? 0) + 1;
    }
    return composition;
  }

  static int? _pickLength(
    Random rng,
    Map<int, List<String>> buckets,
    Map<int, int> used,
  ) {
    final options = <int>[];
    for (var len = _minWordLen; len <= _maxWordLen; len++) {
      final available = (buckets[len]?.length ?? 0) - (used[len] ?? 0);
      if (available > 0) options.add(len);
    }
    if (options.isEmpty) return null;

    final roll = rng.nextDouble();
    final preferred = roll < 0.22
        ? 3
        : roll < 0.70
        ? 4
        : 5;
    if (options.contains(preferred)) return preferred;
    return options[rng.nextInt(options.length)];
  }

  static List<Cell>? _placeTwistyPath({
    required Random rng,
    required int length,
    required Set<Cell> occupied,
    required int size,
  }) {
    final starts = [
      for (var row = 0; row < size; row++)
        for (var col = 0; col < size; col++)
          if (!occupied.contains(Cell(row, col))) Cell(row, col),
    ]..shuffle(rng);
    starts.sort((a, b) => _ringDepth(a, size).compareTo(_ringDepth(b, size)));

    for (final start in starts) {
      final path = <Cell>[start];
      final used = {...occupied, start};
      if (_extendPath(
            path: path,
            used: used,
            length: length,
            rng: rng,
            size: size,
          ) &&
          _isTwistyEnough(path)) {
        return List<Cell>.of(path);
      }
    }
    return null;
  }

  static bool _extendPath({
    required List<Cell> path,
    required Set<Cell> used,
    required int length,
    required Random rng,
    required int size,
  }) {
    if (path.length == length) return true;

    final last = path.last;
    final neighbors = _neighbors(
      last,
      size,
    ).where((cell) => !used.contains(cell)).toList();
    neighbors.shuffle(rng);
    neighbors.sort((a, b) {
      final byRing = _ringDepth(a, size).compareTo(_ringDepth(b, size));
      if (byRing != 0) return byRing;
      if (path.length < 2) return 0;
      final prev = path[path.length - 2];
      final straight = Cell(
        last.row + (last.row - prev.row),
        last.col + (last.col - prev.col),
      );
      final aStraight = a == straight ? 1 : 0;
      final bStraight = b == straight ? 1 : 0;
      return aStraight.compareTo(bStraight);
    });

    for (final next in neighbors) {
      path.add(next);
      used.add(next);
      if (_extendPath(
        path: path,
        used: used,
        length: length,
        rng: rng,
        size: size,
      )) {
        return true;
      }
      used.remove(next);
      path.removeLast();
    }
    return false;
  }

  static bool _isTwistyEnough(List<Cell> path) {
    final turns = _turnCount(path);
    if (path.length <= 3) return turns >= 1;
    return turns >= 2;
  }

  static int _turnCount(List<Cell> path) {
    var turns = 0;
    for (var i = 2; i < path.length; i++) {
      final d1Row = path[i - 1].row - path[i - 2].row;
      final d1Col = path[i - 1].col - path[i - 2].col;
      final d2Row = path[i].row - path[i - 1].row;
      final d2Col = path[i].col - path[i - 1].col;
      if (d1Row != d2Row || d1Col != d2Col) {
        turns++;
      }
    }
    return turns;
  }

  static int _ringDepth(Cell cell, int size) {
    final toRight = size - 1 - cell.col;
    final toBottom = size - 1 - cell.row;
    return min(min(cell.row, cell.col), min(toBottom, toRight));
  }

  static PathWordsPuzzle _trimEmptySquareBorders(PathWordsPuzzle puzzle) {
    var minRow = 0;
    var minCol = 0;
    var maxRow = puzzle.size - 1;
    var maxCol = puzzle.size - 1;

    bool rowEmpty(int row) {
      for (var col = minCol; col <= maxCol; col++) {
        if (puzzle.hasLetter(Cell(row, col))) return false;
      }
      return true;
    }

    bool colEmpty(int col) {
      for (var row = minRow; row <= maxRow; row++) {
        if (puzzle.hasLetter(Cell(row, col))) return false;
      }
      return true;
    }

    var changed = true;
    while (changed && maxRow > minRow && maxCol > minCol) {
      changed = false;
      final top = rowEmpty(minRow);
      final bottom = rowEmpty(maxRow);
      final left = colEmpty(minCol);
      final right = colEmpty(maxCol);
      if (top && bottom && left && right) {
        minRow++;
        maxRow--;
        minCol++;
        maxCol--;
        changed = true;
        continue;
      }
      if (top && left) {
        minRow++;
        minCol++;
        changed = true;
        continue;
      }
      if (top && right) {
        minRow++;
        maxCol--;
        changed = true;
        continue;
      }
      if (bottom && left) {
        maxRow--;
        minCol++;
        changed = true;
        continue;
      }
      if (bottom && right) {
        maxRow--;
        maxCol--;
        changed = true;
      }
    }

    final newSize = maxRow - minRow + 1;
    if (newSize == puzzle.size && minRow == 0 && minCol == 0) {
      return puzzle;
    }

    Cell mapCell(Cell cell) => Cell(cell.row - minRow, cell.col - minCol);
    final letters = List<String>.filled(newSize * newSize, '');
    for (var row = minRow; row <= maxRow; row++) {
      for (var col = minCol; col <= maxCol; col++) {
        final letter = puzzle.letterAt(Cell(row, col));
        if (letter.isEmpty) continue;
        final to = mapCell(Cell(row, col));
        letters[to.row * newSize + to.col] = letter;
      }
    }

    return PathWordsPuzzle(
      id: puzzle.id,
      day: puzzle.day,
      size: newSize,
      letters: letters,
      targets: [
        for (final target in puzzle.targets)
          PathWordsTarget(
            id: target.id,
            word: target.word,
            start: mapCell(target.start),
            path: [for (final cell in target.path) mapCell(cell)],
            colorIndex: target.colorIndex,
          ),
      ],
    );
  }

  static List<Cell> _neighbors(Cell cell, int size) {
    const deltas = <(int, int)>[(-1, 0), (1, 0), (0, -1), (0, 1)];
    final next = <Cell>[];
    for (final delta in deltas) {
      final candidate = Cell(cell.row + delta.$1, cell.col + delta.$2);
      if (candidate.row < 0 ||
          candidate.row >= size ||
          candidate.col < 0 ||
          candidate.col >= size) {
        continue;
      }
      next.add(candidate);
    }
    return next;
  }
}
