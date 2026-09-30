import '../../../domain/entities/cell.dart';
import '../../../domain/entities/path_words_puzzle.dart';

class PathWordsBoardView {
  const PathWordsBoardView({
    required this.puzzle,
    required this.activePath,
    required this.placedPaths,
    required this.completedPathsByTargetId,
    required this.hintPath,
    required this.hintRevealLength,
    required this.celebrate,
    required this.inputEnabled,
  });

  final PathWordsPuzzle puzzle;
  final List<Cell> activePath;
  final List<PathWordsStroke> placedPaths;
  final Map<String, List<Cell>> completedPathsByTargetId;
  final List<Cell> hintPath;
  final int hintRevealLength;
  final bool celebrate;
  final bool inputEnabled;
}
