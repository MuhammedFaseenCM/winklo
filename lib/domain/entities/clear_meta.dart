/// Clean-run flags of the run that set a mode's best time.
///
/// Stored locally next to the best time so leaderboard backfill and remote
/// progress sync can report the real flags instead of conservative guesses.
class ClearMeta {
  const ClearMeta({required this.usedHints, required this.hadMistakes});

  final bool usedHints;
  final bool hadMistakes;

  Map<String, dynamic> toJson() => {
    'usedHints': usedHints,
    'hadMistakes': hadMistakes,
  };

  /// Returns null for anything that is not a map with both bool flags.
  static ClearMeta? fromJson(Object? json) {
    if (json is! Map) return null;
    final usedHints = json['usedHints'];
    final hadMistakes = json['hadMistakes'];
    if (usedHints is! bool || hadMistakes is! bool) return null;
    return ClearMeta(usedHints: usedHints, hadMistakes: hadMistakes);
  }

  @override
  bool operator ==(Object other) =>
      other is ClearMeta &&
      other.usedHints == usedHints &&
      other.hadMistakes == hadMistakes;

  @override
  int get hashCode => Object.hash(usedHints, hadMistakes);

  @override
  String toString() =>
      'ClearMeta(usedHints: $usedHints, hadMistakes: $hadMistakes)';
}
