import 'package:flutter/foundation.dart';

/// Subcollections under `users/{uid}` that hold private per-user progress.
///
/// Debug builds use the `_debug` twins (like [leaderboardRootCollection]) so
/// local runs never touch release progress.
({String gameDays, String gameStreaks}) progressCollections({
  bool? isDebugMode,
}) {
  final debug = isDebugMode ?? kDebugMode;
  return debug
      ? (gameDays: 'game_days_debug', gameStreaks: 'game_streaks_debug')
      : (gameDays: 'game_days', gameStreaks: 'game_streaks');
}
