/// Subcollections under `users/{uid}` that hold private per-user progress.
///
/// App builds (debug and release) use the release names. Pass [isDebugMode]
/// only in tests that need the `_debug` twins (like [leaderboardRootCollection]).
({String gameDays, String gameStreaks}) progressCollections({
  bool? isDebugMode,
}) {
  final debug = isDebugMode ?? false;
  return debug
      ? (gameDays: 'game_days_debug', gameStreaks: 'game_streaks_debug')
      : (gameDays: 'game_days', gameStreaks: 'game_streaks');
}
