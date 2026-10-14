/// Local in-progress draft for a daily timed game.
class InProgressRun {
  const InProgressRun({
    required this.gameId,
    required this.playId,
    required this.elapsedMs,
    required this.board,
    this.usedHintsThisRun = false,
    this.hadMistakesThisRun = false,
    this.boardFingerprint,
  });

  final String gameId;
  final String playId;
  final int elapsedMs;
  final bool usedHintsThisRun;
  final bool hadMistakesThisRun;

  /// Game-specific JSON-encodable board snapshot.
  final Map<String, dynamic> board;

  /// The puzzle's fingerprint when the run was saved. Null for runs saved
  /// before fingerprints existed (builds up to 1.0.0+16).
  final String? boardFingerprint;

  /// False when the day's board was replaced after this run was saved, so
  /// its path, digits or found words no longer fit. Older runs are kept.
  bool isForBoard(String fingerprint) =>
      boardFingerprint == null || boardFingerprint == fingerprint;

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'playId': playId,
    'elapsedMs': elapsedMs,
    'usedHintsThisRun': usedHintsThisRun,
    'hadMistakesThisRun': hadMistakesThisRun,
    'board': board,
    if (boardFingerprint != null) 'boardFingerprint': boardFingerprint,
  };

  factory InProgressRun.fromJson(Map<String, dynamic> json) {
    final boardRaw = json['board'];
    return InProgressRun(
      gameId: json['gameId'] as String,
      playId: json['playId'] as String,
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      usedHintsThisRun: json['usedHintsThisRun'] as bool? ?? false,
      hadMistakesThisRun: json['hadMistakesThisRun'] as bool? ?? false,
      board: boardRaw is Map
          ? Map<String, dynamic>.from(boardRaw)
          : const <String, dynamic>{},
      boardFingerprint: json['boardFingerprint'] as String?,
    );
  }
}
