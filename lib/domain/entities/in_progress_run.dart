/// Local in-progress draft for a daily timed game.
class InProgressRun {
  const InProgressRun({
    required this.gameId,
    required this.playId,
    required this.elapsedMs,
    required this.board,
    this.usedHintsThisRun = false,
    this.hadMistakesThisRun = false,
  });

  final String gameId;
  final String playId;
  final int elapsedMs;
  final bool usedHintsThisRun;
  final bool hadMistakesThisRun;

  /// Game-specific JSON-encodable board snapshot.
  final Map<String, dynamic> board;

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'playId': playId,
    'elapsedMs': elapsedMs,
    'usedHintsThisRun': usedHintsThisRun,
    'hadMistakesThisRun': hadMistakesThisRun,
    'board': board,
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
    );
  }
}
