/// Clean-run flags of the run that set a mode's best time.
///
/// Stored locally next to the best time so leaderboard backfill and remote
/// progress sync can report the real flags instead of conservative guesses.
/// Path Words also keeps the run's bonus words here; they are local only and
/// never affect the flags, the time or the leaderboard.
class ClearMeta {
  const ClearMeta({
    required this.usedHints,
    required this.hadMistakes,
    this.bonusWords = const [],
  });

  final bool usedHints;
  final bool hadMistakes;

  /// Path Words: real words found that weren't targets, in the order found.
  final List<String> bonusWords;

  Map<String, dynamic> toJson() => {
    'usedHints': usedHints,
    'hadMistakes': hadMistakes,
    if (bonusWords.isNotEmpty) 'bonusWords': bonusWords,
  };

  /// Returns null for anything that is not a map with both bool flags.
  static ClearMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    final usedHints = json['usedHints'];
    final hadMistakes = json['hadMistakes'];
    if (usedHints is! bool || hadMistakes is! bool) return null;
    final rawBonus = json['bonusWords'];
    return ClearMeta(
      usedHints: usedHints,
      hadMistakes: hadMistakes,
      bonusWords: [
        if (rawBonus is List)
          for (final word in rawBonus)
            if (word is String) word,
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! ClearMeta ||
        other.usedHints != usedHints ||
        other.hadMistakes != hadMistakes ||
        other.bonusWords.length != bonusWords.length) {
      return false;
    }
    for (var i = 0; i < bonusWords.length; i++) {
      if (other.bonusWords[i] != bonusWords[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(usedHints, hadMistakes, Object.hashAll(bonusWords));

  @override
  String toString() =>
      'ClearMeta(usedHints: $usedHints, hadMistakes: $hadMistakes'
      '${bonusWords.isEmpty ? '' : ', bonusWords: $bonusWords'})';
}
