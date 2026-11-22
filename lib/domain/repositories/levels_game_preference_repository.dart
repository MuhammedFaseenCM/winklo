/// The game the Levels tab was last left on.
abstract class LevelsGamePreferenceRepository {
  /// The remembered game id; Zip when nothing, or a game without Levels, is
  /// stored.
  String read();

  Future<void> write(String gameId);
}
