import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/features/achievements/view/achievement_badge_grid.dart';
import 'package:winklo/features/achievements/view/achievement_copy.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, Set<String> unlocked) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AchievementBadgeGrid(unlocked: unlocked),
          ),
        ),
      ),
    );
  }

  test('copy for every badge', () {
    final first = Achievements.byId('first_clear_path_words')!;
    final streak = Achievements.byId('streak_30_sudoku')!;
    expect(achievementTitle(first), 'First Path Words');
    expect(achievementCondition(first), 'Clear your first Path Words');
    expect(achievementTitle(streak), '30-day Sudoku streak');
    expect(achievementCondition(streak), 'Clear Sudoku 30 days in a row');
    for (final a in Achievements.all) {
      expect(achievementTitle(a), isNotEmpty, reason: a.id);
      expect(achievementCondition(a), isNotEmpty, reason: a.id);
    }
  });

  testWidgets('unlocked badges show their name, locked ones how to earn '
      'them, dimmed', (tester) async {
    await pumpGrid(tester, {'first_clear_zip', 'perfect_day'});

    expect(find.byType(AchievementBadge), findsNWidgets(16));
    expect(find.text(AppStrings.achievementsFirstClearsSection), findsOneWidget);
    expect(find.text(AppStrings.achievementsStreaksSection), findsOneWidget);
    expect(find.text(AppStrings.achievementsSpecialsSection), findsOneWidget);
    expect(find.text('First Zip'), findsOneWidget);
    expect(find.text(AppStrings.achievementPerfectDayTitle), findsOneWidget);
    expect(find.text('Clear your first Sudoku'), findsOneWidget);
    expect(find.text('First Sudoku'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(14));

    double opacityOf(String text) => tester
        .widget<Opacity>(
          find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacityOf('First Zip'), 1);
    expect(opacityOf('Clear your first Sudoku'), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlocked medals use distinct enamel colors by game', (
    tester,
  ) async {
    await pumpGrid(tester, {
      for (final a in Achievements.all) a.id,
    });

    final zip = tester.widget<Container>(
      find
          .descendant(
            of: find.widgetWithText(AchievementBadge, 'First Zip'),
            matching: find.byType(Container),
          )
          .first,
    );
    final path = tester.widget<Container>(
      find
          .descendant(
            of: find.widgetWithText(AchievementBadge, 'First Path Words'),
            matching: find.byType(Container),
          )
          .first,
    );
    final zipGrad = (zip.decoration! as BoxDecoration).gradient!;
    final pathGrad = (path.decoration! as BoxDecoration).gradient!;
    expect(zipGrad.colors.first, isNot(pathGrad.colors.first));
  });

  testWidgets('badges read their state to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpGrid(tester, {'first_clear_zip'});

    expect(
      tester.getSemantics(find.byType(AchievementBadge).first),
      matchesSemantics(label: 'First Zip'),
    );
    expect(
      tester.getSemantics(find.byType(AchievementBadge).at(1)),
      matchesSemantics(
        label: 'First Path Words',
        value: '${AppStrings.achievementLocked}. Clear your first Path Words',
      ),
    );
    handle.dispose();
  });
}
