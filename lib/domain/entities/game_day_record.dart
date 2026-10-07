/// One user's progress on one daily game period ([playId]).
///
/// Mirrors `users/{uid}/game_days/{gameId}_{playId}`. [timeSeconds] is present
/// exactly when the period was cleared.
class GameDayRecord {
  const GameDayRecord({
    required this.gameId,
    required this.playId,
    this.timeSeconds,
    this.points,
    this.usedHints,
    this.hadMistakes,
    this.flagsKnown,
    this.hintsUsed = 0,
    this.clearedAt,
  });

  final String gameId;

  /// `YYYYMMDD` (daily) or `YYYYMMDDHHmm` (debug minute period).
  final String playId;

  /// Best (lowest) clear time.
  final int? timeSeconds;

  /// Best (highest) points.
  final int? points;

  final bool? usedHints;
  final bool? hadMistakes;

  /// False when [usedHints] / [hadMistakes] were derived for a legacy clear.
  final bool? flagsKnown;

  /// Hint quota consumed during the period.
  final int hintsUsed;

  /// First time the clear reached the remote copy.
  final DateTime? clearedAt;

  bool get cleared => timeSeconds != null;

  GameDayRecord copyWith({
    String? gameId,
    String? playId,
    int? timeSeconds,
    int? points,
    bool? usedHints,
    bool? hadMistakes,
    bool? flagsKnown,
    int? hintsUsed,
    DateTime? clearedAt,
  }) {
    return GameDayRecord(
      gameId: gameId ?? this.gameId,
      playId: playId ?? this.playId,
      timeSeconds: timeSeconds ?? this.timeSeconds,
      points: points ?? this.points,
      usedHints: usedHints ?? this.usedHints,
      hadMistakes: hadMistakes ?? this.hadMistakes,
      flagsKnown: flagsKnown ?? this.flagsKnown,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      clearedAt: clearedAt ?? this.clearedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameDayRecord &&
      other.gameId == gameId &&
      other.playId == playId &&
      other.timeSeconds == timeSeconds &&
      other.points == points &&
      other.usedHints == usedHints &&
      other.hadMistakes == hadMistakes &&
      other.flagsKnown == flagsKnown &&
      other.hintsUsed == hintsUsed &&
      other.clearedAt == clearedAt;

  @override
  int get hashCode => Object.hash(
    gameId,
    playId,
    timeSeconds,
    points,
    usedHints,
    hadMistakes,
    flagsKnown,
    hintsUsed,
    clearedAt,
  );

  @override
  String toString() =>
      'GameDayRecord($gameId, $playId, time: $timeSeconds, points: $points, '
      'usedHints: $usedHints, hadMistakes: $hadMistakes, '
      'flagsKnown: $flagsKnown, hintsUsed: $hintsUsed, clearedAt: $clearedAt)';
}
