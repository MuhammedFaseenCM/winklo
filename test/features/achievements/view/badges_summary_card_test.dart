import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/stats/game_stats.dart';
import 'package:winklo/features/achievements/view/achievement_medal.dart';
import 'package:winklo/features/achievements/view/badges_summary_card.dart';
import 'package:winklo/features/stats/cubit/stats_state.dart';

GameStats _stats(String gameId, {int current = 0}) => GameStats(
  gameId: gameId,
  clears: current,
  currentStreak: current,
  longestStreak: current,
  bestSeconds: null,
  averageSeconds: null,
  hintFreeShare: null,
  histogram: const [],
  calendar: const [],
  trend: const [],
);

StatsState _ready(
  Set<String> unlocked, {
  Map<String, int> streaks = const {},
}) => StatsState(
  status: StatsStatus.ready,
  unlocked: unlocked,
  stats: {
    for (final id in [GameIds.zip, GameIds.pathWords, GameIds.sudoku])
      id: _stats(id, current: streaks[id] ?? 0),
  },
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    StatsState state, {
    VoidCallback? onOpen,
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BadgesSummaryCard(state: state, onOpen: onOpen ?? () {}),
          ),
        ),
      ),
    );
  }

  testWidgets('count, earned medals and the next badge with its progress', (
    tester,
  ) async {
    await pump(
      tester,
      _ready(
        const {
          'first_clear_zip',
          'first_clear_path_words',
          'first_clear_sudoku',
        },
        streaks: const {GameIds.pathWords: 4},
      ),
    );

    expect(find.text(AppStrings.achievementsTitle), findsOneWidget);
    expect(find.text(AppStrings.achievementsProgress(3, 16)), findsOneWidget);
    // Three earned medals and the locked one beside Next.
    expect(find.byType(AchievementMedal), findsNWidgets(4));
    expect(
      find.text(AppStrings.achievementNext('7-day Path Words streak')),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.achievementStreakProgress(4, 7)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no streak running, Next says how to earn it', (
    tester,
  ) async {
    await pump(tester, _ready(const {}));
    expect(find.text(AppStrings.achievementNext('First Zip')), findsOneWidget);
    expect(find.text('Clear your first Zip'), findsOneWidget);
    // Nothing earned: only the Next medal.
    expect(find.byType(AchievementMedal), findsOneWidget);
  });

  testWidgets('more earned than fit: the last spot says +N', (tester) async {
    final all = {for (final a in Achievements.all) a.id}..remove('perfect_day');
    await pump(tester, _ready(all), width: 320);
    expect(find.textContaining('+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every badge earned', (tester) async {
    await pump(tester, _ready({for (final a in Achievements.all) a.id}));
    expect(find.text(AppStrings.achievementsAllEarned), findsOneWidget);
    expect(find.textContaining(AppStrings.achievementNext('')), findsNothing);
  });

  testWidgets('loading: no count yet, no Next', (tester) async {
    await pump(tester, const StatsState());
    expect(find.text(AppStrings.achievementsTitle), findsOneWidget);
    expect(find.text(AppStrings.achievementsProgress(0, 16)), findsNothing);
    expect(find.byType(AchievementMedal), findsNothing);
  });

  testWidgets('tapping the card opens the Badges screen', (tester) async {
    var opened = 0;
    await pump(tester, _ready(const {}), onOpen: () => opened++);
    await tester.tap(find.text(AppStrings.achievementsTitle));
    expect(opened, 1);
    expect(
      tester.getSemantics(find.byType(BadgesSummaryCard)),
      isSemantics(isButton: true, hasTapAction: true),
    );
  });
}
