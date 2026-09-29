import 'cell.dart';

/// A stroke released onto the board. [targetId] is set only when it matches
/// a remaining solution path.
class PathWordsStroke {
  const PathWordsStroke({
    required this.cells,
    required this.colorIndex,
    this.targetId,
  });

  final List<Cell> cells;
  final int colorIndex;
  final String? targetId;

  bool get isCorrect => targetId != null;

  @override
  bool operator ==(Object other) {
    if (other is! PathWordsStroke) return false;
    if (colorIndex != other.colorIndex || targetId != other.targetId) {
      return false;
    }
    if (cells.length != other.cells.length) return false;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] != other.cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(colorIndex, targetId, Object.hashAll(cells));
}

/// Letters shown in one word-list row for a live or incorrect stroke.
class PathWordsListFill {
  const PathWordsListFill({
    required this.letters,
    required this.colorIndex,
    required this.slotLength,
  });

  final List<String> letters;
  final int colorIndex;
  final int slotLength;

  int get overflowCount {
    final extra = letters.length - slotLength;
    return extra > 0 ? extra : 0;
  }
}

class PathWordsTarget {
  const PathWordsTarget({
    required this.id,
    required this.word,
    required this.start,
    required this.path,
    required this.colorIndex,
  });

  final String id;
  final String word;
  final Cell start;
  final List<Cell> path;
  final int colorIndex;

  factory PathWordsTarget.fromJson(Map<String, dynamic> json) {
    return PathWordsTarget(
      id: json['id'] as String,
      word: json['word'] as String,
      start: Cell.fromJson(json['start']),
      path: (json['path'] as List).map(Cell.fromJson).toList(),
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'start': start.toList(),
    'path': path.map((c) => c.toList()).toList(),
    'colorIndex': colorIndex,
  };
}

class PathWordsPuzzle {
  const PathWordsPuzzle({
    required this.id,
    required this.day,
    required this.size,
    required this.letters,
    required this.targets,
  });

  final String id;
  final DateTime day;
  final int size;

  /// Row-major, length `size * size`. Lowercase letters, or empty for unused cells.
  final List<String> letters;
  final List<PathWordsTarget> targets;

  String letterAt(Cell cell) => letters[cell.row * size + cell.col];

  bool hasLetter(Cell cell) => letterAt(cell).isNotEmpty;

  factory PathWordsPuzzle.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawLetters = (json['letters'] as List)
        .map((e) => e.toString().toLowerCase())
        .toList();
    final targets = (json['targets'] as List? ?? [])
        .map((t) => PathWordsTarget.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    final rawDay = json['day'];
    final day = rawDay is String
        ? DateTime.tryParse(rawDay) ?? DateTime.now()
        : DateTime.now();
    return PathWordsPuzzle(
      id: id ?? json['id'] as String? ?? '',
      day: day,
      size: (json['size'] as num).toInt(),
      letters: rawLetters,
      targets: targets,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day.toIso8601String(),
    'size': size,
    'letters': letters,
    'targets': targets.map((t) => t.toJson()).toList(),
  };
}
