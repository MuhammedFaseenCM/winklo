/// Top-level Firestore collection for Zip / Path Words leaderboards.
///
/// App builds (debug and release) use [leaderboards]. Pass [isDebugMode]
/// only in tests that need the [leaderboards_debug] twin.
String leaderboardRootCollection({bool? isDebugMode}) {
  final debug = isDebugMode ?? false;
  return debug ? 'leaderboards_debug' : 'leaderboards';
}
