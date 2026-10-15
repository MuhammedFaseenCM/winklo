import '../stable_seed.dart';
import 'cell.dart';
import 'daily_special.dart';

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
    this.theme,
    this.definitions = const {},
    this.special,
  });

  final String id;
  final DateTime day;
  final int size;

  /// Row-major, length `size * size`. Lowercase letters, or empty for unused cells.
  final List<String> letters;
  final List<PathWordsTarget> targets;

  /// The day's theme ("Kitchen tools"), shown only after a clear; null when
  /// the day has none.
  final String? theme;

  /// A one-line definition of each target word, keyed by the word in lower
  /// case; empty when the doc has none. Shown only after a clear.
  final Map<String, String> definitions;

  /// `weekend` on a weekend special (see [DailySpecial]); null otherwise.
  final String? special;

  bool get isWeekendSpecial => special == DailySpecial.weekend;

  /// The definition of [word], in any case; null when there is none.
  String? definitionFor(String word) => definitions[word.toLowerCase()];

  String letterAt(Cell cell) => letters[cell.row * size + cell.col];

  bool hasLetter(Cell cell) => letterAt(cell).isNotEmpty;

  /// Changes whenever the board does, including a target's id, word or path,
  /// since saved runs refer to targets by id. The theme, definitions and
  /// special aren't part of the board, so editing them keeps a saved run.
  String get fingerprint {
    final targetKeys = [
      for (final t in targets) '${t.id}:${t.word}:${t.path.join(' ')}',
    ];
    return boardFingerprint(
      'pathwords|$size|${letters.join(',')}|${targetKeys.join(';')}',
    );
  }

  factory PathWordsPuzzle.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawLetters = (json['letters'] as List)
        .map((e) => e.toString().toLowerCase())
        .toList();
    final targets = (json['targets'] as List? ?? [])
        .map(
          (t) => PathWordsTarget.fromJson(Map<String, dynamic>.from(t as Map)),
        )
        .toList();
    final rawDay = json['day'];
    final day = rawDay is String
        ? DateTime.tryParse(rawDay) ?? DateTime.now()
        : DateTime.now();
    final rawTheme = json['theme'];
    final theme = rawTheme is String && rawTheme.trim().isNotEmpty
        ? rawTheme.trim()
        : null;
    final rawDefinitions = json['definitions'];
    final definitions = <String, String>{
      if (rawDefinitions is Map)
        for (final entry in rawDefinitions.entries)
          if (entry.value is String &&
              (entry.value as String).trim().isNotEmpty)
            entry.key.toString().trim().toLowerCase(): (entry.value as String)
                .trim(),
    };
    return PathWordsPuzzle(
      id: id ?? json['id'] as String? ?? '',
      day: day,
      size: (json['size'] as num).toInt(),
      letters: rawLetters,
      targets: targets,
      theme: theme,
      definitions: definitions,
      special: readDailySpecial(json['special']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day.toIso8601String(),
    'size': size,
    'letters': letters,
    'targets': targets.map((t) => t.toJson()).toList(),
    if (theme != null) 'theme': theme,
    if (definitions.isNotEmpty) 'definitions': definitions,
    if (special != null) 'special': special,
  };
}
