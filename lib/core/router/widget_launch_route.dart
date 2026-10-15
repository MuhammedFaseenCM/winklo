/// Launch URIs of the home-screen widget's rows: `winkloapp://play/<game>`.
/// Flutter hands the launch intent's URI to the router as a deep link.
const widgetLaunchScheme = 'winkloapp';

/// URI game segment -> app route (`WinkloWidgetProvider.kt` uses the keys).
const widgetLaunchGames = {
  'zip': '/zip',
  'path-words': '/path-words',
  'sudoku': '/sudoku',
};

/// Where a widget launch [uri] goes: its game, or Home for anything else
/// under [widgetLaunchScheme]. Null for every other link. The router's
/// sign-in redirect still applies to the result.
String? widgetLaunchLocation(Uri uri) {
  if (uri.scheme != widgetLaunchScheme) return null;
  final segments = uri.pathSegments;
  if (uri.host != 'play' || segments.length != 1) return '/';
  return widgetLaunchGames[segments.single] ?? '/';
}
