import 'package:go_router/go_router.dart';

import 'join_league_screen.dart';
import 'league_detail_screen.dart';
import 'leagues_screen.dart';

/// `/leagues`, `/leagues/{leagueId}` and `/join/{code}` (invite links).
List<RouteBase> leagueRoutes() => [
  GoRoute(
    path: '/leagues',
    name: 'leagues',
    builder: (context, state) => const LeaguesScreen(),
    routes: [
      GoRoute(
        path: ':leagueId',
        name: 'league',
        builder: (context, state) =>
            LeagueDetailScreen(leagueId: state.pathParameters['leagueId']!),
      ),
    ],
  ),
  GoRoute(
    path: '/join/:code',
    name: 'join_league',
    builder: (context, state) =>
        JoinLeagueScreen(code: state.pathParameters['code']!),
  ),
];
