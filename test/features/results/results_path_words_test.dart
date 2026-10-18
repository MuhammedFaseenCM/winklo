import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/path_words_clear_summary.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/repositories/share_repository.dart';
import 'package:winklo/domain/usecases/next_uncleared_daily.dart';
import 'package:winklo/domain/usecases/sign_in_with_google.dart';
import 'package:winklo/domain/usecases/sign_out.dart';
import 'package:winklo/domain/usecases/watch_leaderboard.dart';
import 'package:winklo/features/auth/cubit/auth_cubit.dart';
import 'package:winklo/features/results/results_args.dart';
import 'package:winklo/features/results/results_screen.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_definition_sheet.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_results_panel.dart';

import '../../helpers/mock_analytics_repository.dart';
import '../../helpers/mock_app_review_repository.dart';
import 'package:winklo/domain/repositories/app_review_repository.dart';

class _MockWatchLeaderboard extends Mock implements WatchLeaderboard {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

class _MockNextUnclearedDaily extends Mock implements NextUnclearedDaily {}

class _MockShareRepository extends Mock implements ShareRepository {}

/// What the daily Results actions read; the app always provides them.
List<RepositoryProvider<Object>> _actionProviders() {
  final next = _MockNextUnclearedDaily();
  when(
    () => next(
      justCleared: any(named: 'justCleared'),
      playId: any(named: 'playId'),
    ),
  ).thenReturn(null);
  final analytics = MockAnalyticsRepository();
  stubAnalytics(analytics);
  final review = MockAppReviewRepository();
  stubAppReviewNoAutoPrompt(review);
  return [
    RepositoryProvider<NextUnclearedDaily>.value(value: next),
    RepositoryProvider<AnalyticsRepository>.value(value: analytics),
    RepositoryProvider<AppReviewRepository>.value(value: review),
    RepositoryProvider<ShareRepository>.value(value: _MockShareRepository()),
  ];
}

void main() {
  setUpAll(() {
    registerFallbackValue(LeaderboardPeriod.daily);
  });

  Future<void> pumpResults(WidgetTester tester, ResultsArgs args) async {
    final auth = _MockAuthRepository();
    final boardController =
        StreamController<List<LeaderboardEntry>>.broadcast();
    addTearDown(boardController.close);
    final watch = _MockWatchLeaderboard();
    when(
      () => watch(
        gameId: any(named: 'gameId'),
        period: any(named: 'period'),
        dayId: any(named: 'dayId'),
      ),
    ).thenAnswer((_) => boardController.stream);
    when(
      () => auth.currentUser,
    ).thenReturn(const AppUser(uid: 'u1', displayName: 'Tester'));
    when(() => auth.authStateChanges()).thenAnswer(
      (_) => Stream.value(const AppUser(uid: 'u1', displayName: 'Tester')),
    );
    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(
          path: '/results',
          builder: (_, _) => ResultsScreen(args: args),
        ),
      ],
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<WatchLeaderboard>.value(value: watch),
          RepositoryProvider<AuthRepository>.value(value: auth),
          ..._actionProviders(),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            authRepository: auth,
            signInWithGoogle: _MockSignInWithGoogle(),
            signOut: _MockSignOut(),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    boardController.add(const []);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a Path Words clear reveals the theme, the words and the bonus count',
    (tester) async {
      await pumpResults(
        tester,
        const ResultsArgs(
          title: 'Puzzle cleared!',
          subtitle: '',
          timeSeconds: 42,
          improved: false,
          gameId: GameIds.pathWords,
          pathWords: PathWordsClearSummary(
            theme: 'Kitchen tools',
            words: ['ladle', 'kettle'],
            definitions: {'ladle': 'A deep spoon with a long handle'},
            bonusWords: ['stare', 'tears', 'rates'],
          ),
        ),
      );

      expect(find.byType(PathWordsResultsPanel), findsOneWidget);
      expect(find.text('Today: Kitchen tools'), findsOneWidget);
      expect(find.text('3 bonus words'), findsOneWidget);
      expect(find.text(AppStrings.formatPlayTime(42)), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('pathWordsResultWord_ladle')),
      );
      await tester.tap(find.byKey(const Key('pathWordsResultWord_ladle')));
      await tester.pumpAndSettle();
      expect(find.byType(PathWordsDefinitionSheet), findsOneWidget);
      expect(find.text('A deep spoon with a long handle'), findsOneWidget);
    },
  );

  testWidgets('other games show no Path Words panel', (tester) async {
    await pumpResults(
      tester,
      const ResultsArgs(
        title: 'Puzzle cleared!',
        subtitle: '',
        timeSeconds: 42,
        improved: false,
        gameId: GameIds.zip,
      ),
    );
    expect(find.byType(PathWordsResultsPanel), findsNothing);
    expect(find.textContaining('Today:'), findsNothing);
  });
}
