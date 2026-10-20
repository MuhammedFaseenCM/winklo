import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/leaderboard/logic/board_layout.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_badges.dart';
import 'package:winklo/features/leaderboard/view/widgets/medal_coin.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('the key names only the badges on the board, in order', (
    tester,
  ) async {
    await _pump(
      tester,
      const LeaderboardBadgeKey(
        badges: {LeaderboardBadge.streak, LeaderboardBadge.noHints},
      ),
    );
    expect(find.text(AppStrings.leaderboardNoHintChip), findsOneWidget);
    expect(find.text(AppStrings.leaderboardKeyStreak), findsOneWidget);
    expect(find.text(AppStrings.leaderboardNoMistakesChip), findsNothing);
    expect(
      tester.getCenter(find.text(AppStrings.leaderboardNoHintChip)).dx,
      lessThan(tester.getCenter(find.text(AppStrings.leaderboardKeyStreak)).dx),
    );
    expect(find.byIcon(AppIcons.noHints), findsOneWidget);
    expect(find.byIcon(AppIcons.streak), findsOneWidget);
  });

  testWidgets('no badges, no key', (tester) async {
    await _pump(tester, const LeaderboardBadgeKey(badges: {}));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a medal coin shows its rank', (tester) async {
    await _pump(tester, const MedalCoin(rank: 2));
    expect(find.text('2'), findsOneWidget);
    expect(podiumColor(1), leaderboardGold);
    expect(podiumColor(4), isNull);
  });
}
