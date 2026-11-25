/// What this install has seen of the Levels introduction: the one-time
/// "New: Levels" card, the first-clear tip and the Levels tab (its dot), and
/// the game a level was last started in (where Home's Levels card
/// continues). Kept on this phone only.
abstract class LevelsIntroRepository {
  bool get introSeen;
  Future<void> markIntroSeen();

  bool get firstClearTipSeen;
  Future<void> markFirstClearTipSeen();

  bool get levelsTabSeen;
  Future<void> markLevelsTabSeen();

  /// The game a level was last started in; null before any, or when the
  /// stored game has no Levels.
  String? get lastGame;

  /// Ignored for a game without Levels.
  Future<void> setLastGame(String gameId);

  /// Fires after every write.
  Stream<void> get changes;
}
