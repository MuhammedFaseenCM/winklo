import 'package:flutter/foundation.dart';

/// Top-level Firestore collection for Zip / Path Words leaderboards.
///
/// Debug builds use [leaderboards_debug] so demo seeds and local submits
/// never touch production [leaderboards].
String leaderboardRootCollection({bool? isDebugMode}) {
  final debug = isDebugMode ?? kDebugMode;
  return debug ? 'leaderboards_debug' : 'leaderboards';
}
