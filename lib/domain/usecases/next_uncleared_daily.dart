import '../game_ids.dart';
import 'get_best_points.dart';
import 'get_best_time_seconds.dart';

/// The daily to suggest after clearing one: the next uncleared game after
/// [call]'s `justCleared` in Home's order, wrapping round. Null once every
/// daily for that day is cleared.
class NextUnclearedDaily {
  const NextUnclearedDaily({
    required this._getBestPoints,
    required this._getBestTimeSeconds,
  });

  final GetBestPoints _getBestPoints;
  final GetBestTimeSeconds _getBestTimeSeconds;

  /// Home's tile order.
  static const dailies = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  /// The score key each game saves its daily clear under (as the blocs and
  /// Home build it). Zip keys by the level's doc id (`daily_YYYYMMDD`); the
  /// others by the play id.
  static String modeKeyFor(String gameId, String playId) => switch (gameId) {
    GameIds.zip => 'zip_daily_$playId',
    _ => '${gameId}_$playId',
  };

  String? call({required String justCleared, required String playId}) {
    final start = dailies.indexOf(justCleared);
    for (var step = 1; step <= dailies.length; step++) {
      final gameId = dailies[(start + step) % dailies.length];
      if (gameId == justCleared) continue;
      if (!_isCleared(modeKeyFor(gameId, playId))) return gameId;
    }
    return null;
  }

  // Same test Home uses for "Result" vs "Play today's …".
  bool _isCleared(String modeKey) =>
      _getBestPoints(modeKey) > 0 || _getBestTimeSeconds(modeKey) != null;
}
