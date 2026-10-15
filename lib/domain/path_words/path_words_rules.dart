import '../entities/cell.dart';
import '../entities/path_words_puzzle.dart';

class PathWordsRules {
  PathWordsRules._();

  static Set<Cell> occupiedCells(Iterable<PathWordsStroke> strokes) {
    return {for (final stroke in strokes) ...stroke.cells};
  }

  /// Cells a new stroke must not enter: solved words, where they were traced
  /// (as the board draws them), and every placed stroke.
  static Set<Cell> blockedCells({
    required PathWordsPuzzle puzzle,
    required Set<String> completedTargetIds,
    required List<PathWordsStroke> placedPaths,
  }) {
    return {
      for (final path in completedPaths(
        puzzle: puzzle,
        completedTargetIds: completedTargetIds,
        placedPaths: placedPaths,
      ).values)
        ...path,
      ...occupiedCells(placedPaths),
    };
  }

  /// Pick a palette slot not already used by placed or completed strokes.
  static int nextUnusedColorIndex({
    required PathWordsPuzzle puzzle,
    required Set<String> completedTargetIds,
    required Iterable<PathWordsStroke> placedPaths,
    required int paletteLength,
  }) {
    final used = <int>{
      for (final stroke in placedPaths) stroke.colorIndex % paletteLength,
      for (final target in puzzle.targets)
        if (completedTargetIds.contains(target.id))
          target.colorIndex % paletteLength,
    };
    for (var i = 0; i < paletteLength; i++) {
      if (!used.contains(i)) return i;
    }
    return placedPaths.length % paletteLength;
  }

  /// Commit a released stroke. A solution match keeps the word color; anything
  /// else stays highlighted without claiming a word row.
  static PathWordsStroke commitStroke({
    required PathWordsPuzzle puzzle,
    required List<Cell> cells,
    required Set<String> completedTargetIds,
    required int colorIndex,
  }) {
    final matched = completedTarget(
      puzzle: puzzle,
      path: cells,
      completedTargetIds: completedTargetIds,
    );
    if (matched == null) {
      return PathWordsStroke(
        cells: List<Cell>.from(cells),
        colorIndex: colorIndex,
      );
    }
    return PathWordsStroke(
      cells: List<Cell>.from(cells),
      colorIndex: matched.colorIndex,
      targetId: matched.id,
    );
  }

  /// Truncate an incorrect placed stroke at [cell] (inclusive). Correct words
  /// stay locked. Returns null when [cell] is not on a truncatable stroke.
  static List<PathWordsStroke>? truncatePlacedAt({
    required List<PathWordsStroke> placedPaths,
    required Cell cell,
  }) {
    for (var i = 0; i < placedPaths.length; i++) {
      final stroke = placedPaths[i];
      if (stroke.isCorrect) continue;
      final index = stroke.cells.indexOf(cell);
      if (index < 0) continue;
      final kept = stroke.cells.sublist(0, index + 1);
      final next = List<PathWordsStroke>.from(placedPaths);
      if (kept.length < 2) {
        next.removeAt(i);
      } else {
        next[i] = PathWordsStroke(cells: kept, colorIndex: stroke.colorIndex);
      }
      return next;
    }
    return null;
  }

  /// Truncate the active stroke to [candidate] when it is earlier on the path.
  static List<Cell>? tryTruncate({
    required List<Cell> path,
    required Cell candidate,
  }) {
    if (path.length < 2) return null;
    final index = path.indexOf(candidate);
    if (index < 0 || index >= path.length - 1) return null;
    return path.sublist(0, index + 1);
  }

  static bool hasIncorrectStroke(Iterable<PathWordsStroke> strokes) {
    for (final stroke in strokes) {
      if (!stroke.isCorrect) return true;
    }
    return false;
  }

  /// Index of the latest stroke that found no word, or null when every
  /// stroke is a found word. Undo takes back only these.
  static int? lastIncorrectIndex(List<PathWordsStroke> strokes) {
    for (var i = strokes.length - 1; i >= 0; i--) {
      if (!strokes[i].isCorrect) return i;
    }
    return null;
  }

  /// The letters [cells] spell on [puzzle], in order (lower case).
  static String spell(PathWordsPuzzle puzzle, List<Cell> cells) =>
      cells.map(puzzle.letterAt).join();

  static List<PathWordsStroke> withoutIncorrect(List<PathWordsStroke> strokes) {
    return [
      for (final stroke in strokes)
        if (stroke.isCorrect) stroke,
    ];
  }

  static List<Cell>? tryBegin({
    required PathWordsPuzzle puzzle,
    required Cell cell,
    required Set<Cell> locked,
    required Set<String> completedTargetIds,
  }) {
    if (locked.contains(cell)) {
      return null;
    }
    if (!puzzle.hasLetter(cell)) {
      return null;
    }
    return [cell];
  }

  static List<Cell>? tryExtend({
    required PathWordsPuzzle puzzle,
    required List<Cell> path,
    required Cell candidate,
    required Set<Cell> locked,
  }) {
    if (path.isEmpty) {
      return null;
    }
    final last = path.last;
    if (!_isOrthogonal(last, candidate)) {
      return null;
    }
    if (!_inBounds(puzzle, candidate)) {
      return null;
    }
    if (locked.contains(candidate)) {
      return null;
    }
    if (!puzzle.hasLetter(candidate)) {
      return null;
    }
    if (path.contains(candidate)) {
      return null;
    }
    return [...path, candidate];
  }

  /// Pop only the last cell when [candidate] is the previous cell (LIFO).
  static List<Cell>? tryLifoBacktrack({
    required List<Cell> path,
    required Cell candidate,
  }) {
    if (path.length < 2) {
      return null;
    }
    if (candidate != path[path.length - 2]) {
      return null;
    }
    return path.sublist(0, path.length - 1);
  }

  static PathWordsTarget? activeTarget({
    required PathWordsPuzzle puzzle,
    required List<Cell> activePath,
    required Set<String> completedTargetIds,
  }) {
    if (activePath.isEmpty) {
      return null;
    }
    final start = activePath.first;
    PathWordsTarget? fallback;
    for (final target in puzzle.targets) {
      if (completedTargetIds.contains(target.id)) {
        continue;
      }
      fallback ??= target;
      final reversed = target.path.reversed.toList();
      if (start == target.start ||
          start == reversed.first ||
          _isPrefix(activePath, target.path) ||
          _isPrefix(activePath, reversed)) {
        return target;
      }
    }
    return fallback;
  }

  /// Empty word-list row to fill while dragging, without revealing the official word.
  static PathWordsTarget? liveFillTarget({
    required PathWordsPuzzle puzzle,
    required List<Cell> activePath,
    required Set<String> completedTargetIds,
  }) {
    if (activePath.isEmpty) return null;
    final empty = [
      for (final target in orderedTargets(puzzle))
        if (!completedTargetIds.contains(target.id)) target,
    ];
    if (empty.isEmpty) return null;

    final n = activePath.length;
    final exact = [
      for (final t in empty)
        if (t.word.length == n) t,
    ];
    if (exact.isNotEmpty) {
      return exact[_stablePick(activePath, exact.length)];
    }
    final longer = [
      for (final t in empty)
        if (t.word.length > n) t,
    ];
    if (longer.isNotEmpty) return longer.first;
    return empty.last;
  }

  static List<PathWordsTarget> orderedTargets(PathWordsPuzzle puzzle) {
    return [...puzzle.targets]..sort((a, b) {
      final byLength = a.word.length.compareTo(b.word.length);
      if (byLength != 0) return byLength;
      return a.id.compareTo(b.id);
    });
  }

  /// Letters shown in a word-list row for an incorrect or in-progress stroke.
  /// [letters] may be longer than the row when the path overflows the longest
  /// remaining word (extra letters render with a cross).
  static Map<String, PathWordsListFill> listFills({
    required PathWordsPuzzle puzzle,
    required Set<String> completedTargetIds,
    required List<PathWordsStroke> placedPaths,
    required List<Cell> activePath,
  }) {
    final available = [
      for (final target in orderedTargets(puzzle))
        if (!completedTargetIds.contains(target.id)) target,
    ];
    if (available.isEmpty) return const {};

    final strokes = <({List<Cell> cells, int colorIndex})>[
      for (final stroke in placedPaths)
        if (!stroke.isCorrect)
          (cells: stroke.cells, colorIndex: stroke.colorIndex),
    ];
    if (activePath.isNotEmpty) {
      strokes.add((
        cells: activePath,
        colorIndex: nextUnusedColorIndex(
          puzzle: puzzle,
          completedTargetIds: completedTargetIds,
          placedPaths: placedPaths,
          paletteLength: 8,
        ),
      ));
    }

    final claimed = <String>{};
    final fills = <String, PathWordsListFill>{};
    for (final stroke in strokes) {
      if (stroke.cells.isEmpty) continue;
      final slot = _slotForLength(
        available: [
          for (final target in available)
            if (!claimed.contains(target.id)) target,
        ],
        length: stroke.cells.length,
      );
      if (slot == null) continue;
      claimed.add(slot.id);
      fills[slot.id] = PathWordsListFill(
        letters: [
          for (final cell in stroke.cells) puzzle.letterAt(cell).toUpperCase(),
        ],
        colorIndex: stroke.colorIndex,
        slotLength: slot.word.length,
      );
    }
    return fills;
  }

  static PathWordsTarget? _slotForLength({
    required List<PathWordsTarget> available,
    required int length,
  }) {
    if (available.isEmpty) return null;
    for (final target in available) {
      if (target.word.length == length) return target;
    }
    for (final target in available) {
      if (target.word.length > length) return target;
    }
    // Path longer than every remaining slot — overflow onto the longest.
    return available.last;
  }

  static int _stablePick(List<Cell> path, int count) {
    final first = path.first;
    return (first.row * 31 + first.col * 17 + path.length * 13).abs() % count;
  }

  /// Cells to draw for each found word: the stroke the player traced, which
  /// can differ from the stored route, or the stored route when no stroke is
  /// kept (review mode).
  static Map<String, List<Cell>> completedPaths({
    required PathWordsPuzzle puzzle,
    required Set<String> completedTargetIds,
    required List<PathWordsStroke> placedPaths,
  }) {
    final traced = {
      for (final stroke in placedPaths)
        if (stroke.targetId != null) stroke.targetId!: stroke.cells,
    };
    return {
      for (final target in puzzle.targets)
        if (completedTargetIds.contains(target.id))
          target.id: traced[target.id] ?? target.path,
    };
  }

  static PathWordsTarget? completedTarget({
    required PathWordsPuzzle puzzle,
    required List<Cell> path,
    required Set<String> completedTargetIds,
  }) {
    final remaining = [
      for (final target in puzzle.targets)
        if (!completedTargetIds.contains(target.id)) target,
    ];
    for (final target in remaining) {
      if (_pathsEqual(path, target.path)) {
        return target;
      }
    }
    // Hand-made boards can hide a word along more than one route. Accept any
    // route that spells it, as long as it stays off every other word's cells:
    // taking those would leave that word impossible to trace.
    final spelled = path.map(puzzle.letterAt).join();
    for (final target in remaining) {
      if (target.word.toLowerCase() != spelled) continue;
      final othersCells = {
        for (final other in puzzle.targets)
          if (other.id != target.id) ...other.path,
      };
      if (path.any(othersCells.contains)) continue;
      return target;
    }
    return null;
  }

  /// True when the released path fully fills the longest remaining word length
  /// but does not match any solution (user finished drawing every cell of that
  /// attempt and still missed).
  static bool looksLikeFailedWordAttempt({
    required PathWordsPuzzle puzzle,
    required List<Cell> path,
    required Set<String> completedTargetIds,
  }) {
    if (path.length < 2) return false;
    if (completedTarget(
          puzzle: puzzle,
          path: path,
          completedTargetIds: completedTargetIds,
        ) !=
        null) {
      return false;
    }

    var longestRemaining = 0;
    var hasExactLength = false;
    for (final target in puzzle.targets) {
      if (completedTargetIds.contains(target.id)) continue;
      if (target.path.length > longestRemaining) {
        longestRemaining = target.path.length;
      }
      if (target.path.length == path.length) {
        hasExactLength = true;
      }
    }
    if (!hasExactLength) return false;
    // Wait until every cell of the longest remaining word was drawn.
    return path.length == longestRemaining;
  }

  static List<Cell> hintedPath({
    required PathWordsPuzzle puzzle,
    required Set<String> completedTargetIds,
    required int revealedLength,
  }) {
    if (revealedLength <= 0) {
      return const [];
    }
    for (final target in puzzle.targets) {
      if (completedTargetIds.contains(target.id)) {
        continue;
      }
      final end = revealedLength < target.path.length
          ? revealedLength
          : target.path.length;
      return target.path.sublist(0, end);
    }
    return const [];
  }

  static List<Cell> undoActive(List<Cell> path) {
    if (path.isEmpty) {
      return path;
    }
    return path.sublist(0, path.length - 1);
  }

  static bool _isOrthogonal(Cell from, Cell to) {
    final dr = (to.row - from.row).abs();
    final dc = (to.col - from.col).abs();
    return dr + dc == 1;
  }

  static bool _inBounds(PathWordsPuzzle puzzle, Cell cell) {
    return cell.row >= 0 &&
        cell.row < puzzle.size &&
        cell.col >= 0 &&
        cell.col < puzzle.size;
  }

  static bool _pathsEqual(List<Cell> a, List<Cell> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _isPrefix(List<Cell> prefix, List<Cell> full) {
    if (prefix.length > full.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != full[i]) {
        return false;
      }
    }
    return true;
  }
}
