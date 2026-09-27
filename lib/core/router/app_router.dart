import 'package:go_router/go_router.dart';

import '../../domain/repositories/analytics_repository.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/cubit/auth_state.dart';
import '../../features/category_race/view/category_race_screen.dart';
import '../../features/dashboard/view/dashboard_shell.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/leaderboard/view/leaderboard_screen.dart';
import '../../features/path_words/view/path_words_screen.dart';
import '../../features/profile/view/privacy_webview_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/profile/view/report_issue_screen.dart';
import '../../features/results/results_args.dart';
import '../../features/results/results_screen.dart';
import '../../features/sudoku/view/sudoku_screen.dart';
import '../../features/word_match/view/word_match_screen.dart';
import '../../features/word_match/view/word_match_select_screen.dart';
import '../../features/zip/view/zip_screen.dart';
import '../../domain/game_ids.dart';
import '../errors/client_error_route_observer.dart';
import '../firebase/analytics_route_observer.dart';
import 'auth_router_refresh.dart';

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

GoRouter buildRouter({
  required AnalyticsRepository analytics,
  required AuthCubit authCubit,
}) {
  final refresh = AuthRouterRefresh(authCubit);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => playAuthRedirect(
      status: authCubit.state.status,
      isSignedIn: authCubit.isSignedIn,
      matchedLocation: state.matchedLocation,
    ),
    observers: [AnalyticsRouteObserver(analytics), ClientErrorRouteObserver()],
    routes: [
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
                  GoRoute(
                    path: 'privacy',
                    name: 'profile_privacy',
                    builder: (context, state) => const PrivacyWebViewScreen(),
                  ),
                  GoRoute(
                    path: 'report',
                    name: 'profile_report',
                    builder: (context, state) => const ReportIssueScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/zip',
        name: 'zip',
        builder: (context, state) => const ZipScreen(),
      ),
      GoRoute(
        path: '/path-words',
        name: 'path_words',
        builder: (context, state) => const PathWordsScreen(),
      ),
      GoRoute(
        path: '/sudoku',
        name: 'sudoku',
        builder: (context, state) => const SudokuScreen(),
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
              : const ResultsArgs(
                  title: 'Results',
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
