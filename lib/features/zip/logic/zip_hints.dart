import '../../../domain/entities/cell.dart';

abstract final class ZipHints {
  static int startIndex({
    required List<Cell> solution,
    required List<Cell> path,
  }) {
    if (solution.length < 2) return solution.length;
    if (path.isEmpty) return 1;
    return _matchingPrefixLength(solution, path);
  }

  static List<Cell> revealedCells({
    required List<Cell> solution,
    required List<Cell> path,
    required int fromIndex,
    required int revealLength,
  }) {
    if (revealLength <= 0 || fromIndex >= solution.length) return const [];
    final end = fromIndex + revealLength;
    final cells = solution.sublist(
      fromIndex,
      end > solution.length ? solution.length : end,
    );
    if (path.isEmpty) return cells;
    final drawn = path.toSet();
    return [
      for (final cell in cells)
        if (!drawn.contains(cell)) cell,
    ];
  }

  static ({int fromIndex, int revealLength}) afterHint({
    required List<Cell> solution,
    required List<Cell> path,
    required int fromIndex,
    required int revealLength,
  }) {
    final currentStart = startIndex(solution: solution, path: path);
    if (revealLength == 0 || currentStart >= fromIndex + revealLength) {
      return (fromIndex: currentStart, revealLength: 1);
    }
    return (fromIndex: fromIndex, revealLength: revealLength + 1);
  }

  static bool canReveal({
    required List<Cell> solution,
    required List<Cell> path,
    required int fromIndex,
    required int revealLength,
  }) {
    final next = afterHint(
      solution: solution,
      path: path,
      fromIndex: fromIndex,
      revealLength: revealLength,
    );
    // Hints cost time, so only offer one that shows a cell not shown yet.
    final shown = revealedCells(
      solution: solution,
      path: path,
      fromIndex: fromIndex,
      revealLength: revealLength,
    ).toSet();
    return revealedCells(
      solution: solution,
      path: path,
      fromIndex: next.fromIndex,
      revealLength: next.revealLength,
    ).any((cell) => !shown.contains(cell));
  }

  static int _matchingPrefixLength(List<Cell> solution, List<Cell> path) {
    var i = 0;
    final n = solution.length < path.length ? solution.length : path.length;
    while (i < n && solution[i] == path[i]) {
      i++;
    }
    return i;
  }
}
