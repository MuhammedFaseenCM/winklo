/// What Results shows about a Path Words clear: the day's theme, the words
/// found (in word-list order, lower case) with their definitions, and the
/// bonus words.
class PathWordsClearSummary {
  const PathWordsClearSummary({
    required this.words,
    this.theme,
    this.definitions = const {},
    this.bonusWords = const [],
  });

  final String? theme;
  final List<String> words;

  /// Keyed by the word in lower case; a word without one has no entry.
  final Map<String, String> definitions;
  final List<String> bonusWords;

  String? definitionFor(String word) => definitions[word.toLowerCase()];
}
