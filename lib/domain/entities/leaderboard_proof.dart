import '../path_words/path_words_rules.dart';
import 'cell.dart';
import 'path_words_puzzle.dart';

/// What a cleared run sends the leaderboard Worker so it can check the clear
/// against the stored puzzle (`workers/leaderboard/src/proofs.ts`).
sealed class LeaderboardProof {
  const LeaderboardProof();

  /// The `proof` field of the Worker's submit body.
  Map<String, Object?> toJson();
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
