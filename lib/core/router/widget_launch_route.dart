/// Launch URIs of the home-screen widget's rows: `winkloapp://play/<game>`.
/// Flutter hands the launch intent's URI to the router as a deep link, both
/// on a cold start (the initial route) and on a tap while the app is running
/// (`onNewIntent` -> `pushRouteInformation`; MainActivity is singleTop). So
/// the app doesn't also listen to home_widget's
/// `initiallyLaunchedFromHomeWidget` or `widgetClicked`: they carry the same
/// tap and would open the game twice.
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
