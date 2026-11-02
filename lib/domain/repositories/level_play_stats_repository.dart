/// One counted moment of a level run.
enum LevelPlayEvent {
  /// A new run: the board loaded with no saved run to resume.
  start('starts'),

  /// A cleared run.
  clear('clears'),

  /// A hint spent.
  hint('hints');

  const LevelPlayEvent(this.field);

  /// The counter's field in `users/{uid}/level_stats/{game}.levels.{id}`.
  final String field;
}

/// Play counters for the admin's Levels views:
/// `users/{uid}/level_stats/{game}` = `{levels: {id: {starts, clears, hints,
/// lastPlayedAt}}, updatedAt}`. Written with server-side increments, so two
/// devices add up instead of overwriting. The app never reads it back.
abstract interface class LevelPlayStatsRepository {
  /// Adds 1 to [event]'s counter for [levelId] and stamps `lastPlayedAt`.
  Future<void> increment(
    String uid,
    String game,
    String levelId,
    LevelPlayEvent event,
  );
}
