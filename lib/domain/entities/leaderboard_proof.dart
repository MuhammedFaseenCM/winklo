import '../game_ids.dart';
import '../path_words/path_words_rules.dart';
import 'cell.dart';
import 'path_words_puzzle.dart';

/// What a cleared run sends the leaderboard Worker so it can check the clear
/// against the stored puzzle (`workers/leaderboard/src/proofs.ts`).
sealed class LeaderboardProof {
  const LeaderboardProof();

  /// The `proof` field of the Worker's submit body.
  Map<String, Object?> toJson();

  /// A [gameId] proof from what [toJson] wrote (a clear's saved proof); null
  /// when [json] isn't one.
  static LeaderboardProof? fromJson(String gameId, Object? json) {
    if (json is! Map) return null;
    switch (gameId) {
      case GameIds.zip:
        final path = _cells(json['path']);
        return path == null ? null : ZipLeaderboardProof(path);
      case GameIds.sudoku:
        final grid = json['grid'];
        if (grid is! List || grid.any((v) => v is! int)) return null;
        return SudokuLeaderboardProof(grid.cast<int>());
      case GameIds.pathWords:
        final strokes = json['strokes'];
        if (strokes is! List) return null;
        final parsed = <PathWordsProofStroke>[];
        for (final stroke in strokes) {
          if (stroke is! Map) return null;
          final targetId = stroke['targetId'];
          final cells = _cells(stroke['cells']);
          if (targetId is! String || cells == null) return null;
          parsed.add(PathWordsProofStroke(targetId: targetId, cells: cells));
        }
        return PathWordsLeaderboardProof(parsed);
    }
    return null;
  }

  /// `[[row, col], …]` as cells; null when any isn't a pair of ints.
  static List<Cell>? _cells(Object? json) {
    if (json is! List) return null;
    final cells = <Cell>[];
    for (final cell in json) {
      if (cell case [final int row, final int col]) {
        cells.add(Cell(row, col));
      } else {
        return null;
      }
    }
    return cells;
  }
}

/// Zip: the cells in the order they were drawn.
final class ZipLeaderboardProof extends LeaderboardProof {
  const ZipLeaderboardProof(this.path);

  /// From a saved clear's `board` (`row,col` cells joined by `;`, as
  /// `ZipBoardCodec` writes it); null when it's missing or malformed.
  static ZipLeaderboardProof? fromBoard(String? board) {
    if (board == null || board.isEmpty) return null;
    final path = <Cell>[];
    for (final part in board.split(';')) {
      final rc = part.split(',');
      if (rc.length != 2) return null;
      final row = int.tryParse(rc[0]);
      final col = int.tryParse(rc[1]);
      if (row == null || col == null || row < 0 || col < 0) return null;
      path.add(Cell(row, col));
    }
    return ZipLeaderboardProof(path);
  }

  final List<Cell> path;

  @override
  Map<String, Object?> toJson() => {
    'path': [for (final cell in path) cell.toList()],
  };
}

/// Sudoku: the finished grid, row by row (36 digits).
final class SudokuLeaderboardProof extends LeaderboardProof {
  const SudokuLeaderboardProof(this.grid);

  final List<int> grid;

  @override
  Map<String, Object?> toJson() => {'grid': List<int>.of(grid)};
}

/// One found word and the cells it was traced along.
final class PathWordsProofStroke {
  const PathWordsProofStroke({required this.targetId, required this.cells});

  final String targetId;
  final List<Cell> cells;

  Map<String, Object?> toJson() => {
    'targetId': targetId,
    'cells': [for (final cell in cells) cell.toList()],
  };
}

/// Path Words: every word, as traced.
final class PathWordsLeaderboardProof extends LeaderboardProof {
  const PathWordsLeaderboardProof(this.strokes);

  /// The found words of a finished run, as traced (or along the stored
  /// route when a word's stroke wasn't kept), in the puzzle's order.
  factory PathWordsLeaderboardProof.fromRun({
    required PathWordsPuzzle puzzle,
    required Set<String> completedTargetIds,
    required List<PathWordsStroke> placedPaths,
  }) {
    final paths = PathWordsRules.completedPaths(
      puzzle: puzzle,
      completedTargetIds: completedTargetIds,
      placedPaths: placedPaths,
    );
    return PathWordsLeaderboardProof([
      for (final MapEntry(key: targetId, value: cells) in paths.entries)
        PathWordsProofStroke(targetId: targetId, cells: cells),
    ]);
  }

  final List<PathWordsProofStroke> strokes;

  @override
  Map<String, Object?> toJson() => {
    'strokes': [for (final stroke in strokes) stroke.toJson()],
  };
}
