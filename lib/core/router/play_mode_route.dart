import '../../domain/game_ids.dart';
import '../../domain/play_mode.dart';

/// The hub of archive, practice and bonus games.
const moreWaysLocation = '/more';

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
/// [playModeRedirect] sends such links to the archive first.
PlayMode playModeOf(Uri uri, {DateTime? now}) =>
    PlayMode.fromQuery(uri.queryParameters, now: now ?? DateTime.now()) ??
    PlayMode.daily;

/// Sends a game link whose archive day is malformed, today, in the future
/// or before the archive began to that game's archive calendar, so it never
/// opens today's puzzle unranked. Null for everything else.
String? playModeRedirect(Uri uri, {required String gameId, DateTime? now}) {
  if (uri.queryParameters['mode'] != 'archive') return null;
  final mode = PlayMode.fromQuery(
    uri.queryParameters,
    now: now ?? DateTime.now(),
  );
  return mode == null ? archiveLocation(gameId) : null;
}
