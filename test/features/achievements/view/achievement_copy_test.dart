import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/achievements/achievement.dart';
import 'package:winklo/features/achievements/view/achievement_copy.dart';
import 'package:winklo/features/achievements/view/achievement_medal.dart';

void main() {
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

  testWidgets('a locked medal carries a lock, an earned one does not', (
    tester,
  ) async {
    final badge = Achievements.all.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Row(
            children: [
              AchievementMedal(achievement: badge, unlocked: true, size: 40),
              const SizedBox(width: 20),
              AchievementMedal(achievement: badge, unlocked: false, size: 40),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(achievementIcon(badge)), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(AchievementMedal).first),
      const Size(40, 40),
    );
  });
}
