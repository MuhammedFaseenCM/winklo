import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/repositories/analytics_repository.dart';
import '../../features/achievements/view/badges_screen.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/cubit/auth_state.dart';
import '../../features/category_race/view/category_race_screen.dart';
import '../../features/dashboard/view/dashboard_shell.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/leaderboard/view/leaderboard_screen.dart';
import '../../features/leagues/view/league_routes.dart';
import '../../features/levels/view/levels_screen.dart';
import '../../features/more_play/view/archive_screen.dart';
import '../../features/more_play/view/more_play_screen.dart';
import '../../features/path_words/view/path_words_screen.dart';
import '../../features/profile/view/privacy_webview_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/profile/view/report_issue_screen.dart';
import '../../features/results/results_args.dart';
import '../../features/results/results_screen.dart';
import '../../features/settings/view/settings_screen.dart';
import '../../features/stats/view/stats_screen.dart';
import '../../features/sudoku/view/sudoku_screen.dart';
import '../../features/word_match/view/word_match_screen.dart';
import '../../features/word_match/view/word_match_select_screen.dart';
import '../../features/zip/view/zip_screen.dart';
import '../../domain/game_ids.dart';
import '../errors/client_error_route_observer.dart';
import '../strings/app_strings.dart';
import '../firebase/analytics_route_observer.dart';
import 'auth_router_refresh.dart';
import 'play_mode_route.dart';
import 'widget_launch_route.dart';

bool isPlayableLocation(String path) {
  if (path == '/zip' ||
      path == '/path-words' ||
      path == '/sudoku' ||
      path == '/word-match' ||
      path == '/category-race') {
    return true;
  }
  return path.startsWith('/word-match/');
}

String? playAuthRedirect({
  required AuthStatus status,
  required bool isSignedIn,
  required String matchedLocation,
}) {
  if (!isPlayableLocation(matchedLocation)) return null;
  if (status == AuthStatus.unknown) return null;
  if (isSignedIn) return null;
  return '/';
}

/// The `/levels` page, keyed on `open=` and `extra`, so:
/// - an in-app trip (Results' Next level and Map, a failed level's Map)
///   passes a fresh [levelsVisitToken]: a fresh map that places itself and
///   opens `open=`'s sheet, even for the same `open=` as last time;
/// - switching tabs back restores the branch's last location with the same
///   token: the map is kept, and no sheet reopens;
/// - re-tapping the active Levels tab goes to the branch's initial
///   `/levels` with no `extra`: a fresh map when the one on screen came
///   with `open=` or a visit token; one already keyed `(null, null)` (a
///   cold start, an earlier re-tap) is kept as it is, scroll and all;
/// - a router refresh (every auth emission) replays the token through its
///   JSON round trip unchanged: the map is kept;
/// - a cold start or a deep link has no `extra` (null): a fresh map.
Widget buildLevelsRoute(BuildContext context, GoRouterState state) {
  final open = state.uri.queryParameters['open'];
  return LevelsScreen(key: ValueKey((open, state.extra)), openLevelId: open);
}

GoRouter buildRouter({
  required AnalyticsRepository analytics,
  required AuthCubit authCubit,
}) {
  // Profile sub-screens push on this key so the dashboard bottom nav is
  // not shown on top of them.
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final refresh = AuthRouterRefresh(authCubit);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) =>
        widgetLaunchLocation(state.uri) ??
        playAuthRedirect(
          status: authCubit.state.status,
          isSignedIn: authCubit.isSignedIn,
          matchedLocation: state.matchedLocation,
        ),
    observers: [AnalyticsRouteObserver(analytics), ClientErrorRouteObserver()],
    routes: [
      // First, so `/join/{code}` reaches the join screen.
      ...leagueRoutes(),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: levelsLocation,
                name: 'levels',
                builder: buildLevelsRoute,
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                name: 'leaderboard',
                builder: (context, state) {
                  final game = state.uri.queryParameters['game'];
                  final initialGameId = switch (game) {
                    GameIds.pathWords => GameIds.pathWords,
                    GameIds.sudoku => GameIds.sudoku,
                    _ => GameIds.zip,
                  };
                  return LeaderboardScreen(initialGameId: initialGameId);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  // Full-screen over the shell (no bottom nav).
                  GoRoute(
                    path: 'privacy',
                    name: 'profile_privacy',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const PrivacyWebViewScreen(),
                  ),
                  GoRoute(
                    path: 'report',
                    name: 'profile_report',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ReportIssueScreen(),
                  ),
                  GoRoute(
                    path: 'stats',
                    name: 'profile_stats',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const StatsScreen(),
                  ),
                  GoRoute(
                    path: 'badges',
                    name: 'profile_badges',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const BadgesScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    name: 'profile_settings',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // `?mode=archive&day=yyyy-MM-dd` or `?mode=practice`; no mode is the
      // daily, so App Links and the widget are unchanged.
      GoRoute(
        path: '/zip',
        name: 'zip',
        redirect: (context, state) =>
            playModeRedirect(state.uri, gameId: GameIds.zip),
        builder: (context, state) {
          final mode = playModeOf(state.uri);
          // A new mode on the same path (an App Link over an open game)
          // must build a new run, not relabel the old one.
          return ZipScreen(key: ValueKey(mode), mode: mode);
        },
      ),
      GoRoute(
        path: '/path-words',
        name: 'path_words',
        redirect: (context, state) =>
            playModeRedirect(state.uri, gameId: GameIds.pathWords),
        builder: (context, state) {
          final mode = playModeOf(state.uri);
          return PathWordsScreen(key: ValueKey(mode), mode: mode);
        },
      ),
      GoRoute(
        path: '/sudoku',
        name: 'sudoku',
        redirect: (context, state) =>
            playModeRedirect(state.uri, gameId: GameIds.sudoku),
        builder: (context, state) {
          final mode = playModeOf(state.uri);
          return SudokuScreen(key: ValueKey(mode), mode: mode);
        },
      ),
      GoRoute(
        path: moreWaysLocation,
        name: 'more_play',
        builder: (context, state) => const MorePlayScreen(),
        routes: [
          GoRoute(
            path: 'archive',
            name: 'archive',
            builder: (context, state) => ArchiveScreen(
              initialGameId: state.uri.queryParameters['game'] ?? GameIds.zip,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/word-match',
        name: 'word_match_select',
        builder: (context, state) => const WordMatchSelectScreen(),
      ),
      GoRoute(
        path: '/word-match/:deckId',
        name: 'word_match',
        builder: (context, state) =>
            WordMatchScreen(deckId: state.pathParameters['deckId']!),
      ),
      GoRoute(
        path: '/category-race',
        name: 'category_race',
        builder: (context, state) => const CategoryRaceScreen(),
      ),
      GoRoute(
        path: '/results',
        name: 'results',
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is ResultsArgs
              ? extra
              : ResultsArgs(
                  title: AppStrings.resultsTitle,
                  subtitle: '',
                  timeSeconds: 0,
                  improved: false,
                );
          return ResultsScreen(args: args);
        },
      ),
    ],
  );
}
