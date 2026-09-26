import 'package:go_router/go_router.dart';

import '../../domain/repositories/analytics_repository.dart';
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
import '../../features/word_match/view/word_match_screen.dart';
import '../../features/word_match/view/word_match_select_screen.dart';
import '../../features/zip/view/zip_screen.dart';
import '../../domain/game_ids.dart';
import '../firebase/analytics_route_observer.dart';

GoRouter buildRouter({required AnalyticsRepository analytics}) {
  return GoRouter(
    initialLocation: '/',
    observers: [AnalyticsRouteObserver(analytics)],
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
                  return LeaderboardScreen(
                    initialGameId: game == GameIds.pathWords
                        ? GameIds.pathWords
                        : GameIds.zip,
                  );
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
