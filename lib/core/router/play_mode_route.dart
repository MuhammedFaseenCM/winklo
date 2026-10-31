import '../../domain/game_ids.dart';
import '../../domain/play_mode.dart';

/// The hub of archive, practice and bonus games.
const moreWaysLocation = '/more';

/// The Levels tab.
const levelsLocation = '/levels';

/// The Levels tab with [levelId]'s sheet open (Results' Next level).
String levelsOpenLocation(String levelId) => '$levelsLocation?open=$levelId';

int _lastLevelsVisitToken = 0;

/// A fresh, JSON-safe `extra` for an in-app trip to the map: go_router
/// serialises `extra` and replays it on refresh, so it must survive a JSON
/// round trip and compare by value. Never the same twice in a run.
int levelsVisitToken() {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastLevelsVisitToken = now > _lastLevelsVisitToken
      ? now
      : _lastLevelsVisitToken + 1;
  return _lastLevelsVisitToken;
}

/// The archive calendar, optionally opened on [gameId].
String archiveLocation([String? gameId]) =>
    gameId == null ? '/more/archive' : '/more/archive?game=$gameId';

/// The route of a daily game.
String gameRoute(String gameId) => switch (gameId) {
  GameIds.pathWords => '/path-words',
  GameIds.sudoku => '/sudoku',
  _ => '/zip',
};

/// The play mode a game route's [uri] asks for. A missing mode is the daily
/// (App Links, the widget and notifications keep opening today's puzzle).
/// An archive day that isn't in the archive falls back to the daily here;
/// [playModeRedirect] sends such links to the archive first. A malformed
/// level id falls back to the daily too; [playModeRedirect] sends such links
/// to the Levels tab first.
PlayMode playModeOf(Uri uri, {DateTime? now}) =>
    PlayMode.fromQuery(uri.queryParameters, now: now ?? DateTime.now()) ??
    PlayMode.daily;

/// Games with Levels so far; Path Words and Sudoku join later.
const levelGameIds = {GameIds.zip};

/// Sends a game link whose archive day is malformed, today, in the future
/// or before the archive began to that game's archive calendar, and a
/// malformed level link, a level link on a game without Levels, or a level
/// of another game, to the Levels tab, so none of them opens today's puzzle
/// unranked. That holds signed in; signed out, app_router.dart's
/// `playAuthRedirect` sends the player Home first. Null for everything else.
String? playModeRedirect(Uri uri, {required String gameId, DateTime? now}) {
  final kind = uri.queryParameters['mode'];
  if (kind != 'archive' && kind != 'level') return null;
  final mode = PlayMode.fromQuery(
    uri.queryParameters,
    now: now ?? DateTime.now(),
  );
  if (mode == null) {
    return kind == 'archive' ? archiveLocation(gameId) : levelsLocation;
  }
  if (mode.isLevel &&
      (!levelGameIds.contains(gameId) ||
          !mode.levelId!.startsWith('${gameId}_'))) {
    return levelsLocation;
  }
  return null;
}
