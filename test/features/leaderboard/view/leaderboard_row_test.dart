import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_row.dart';

LeaderboardEntry entry(int rank) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Player $rank',
  timeSeconds: 30,
  updatedAt: DateTime.utc(2026, 9, 24),
  rank: rank,
);

void main() {
  testWidgets('rank 1 shows gold medal asset, not numeral', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(
            entry: entry(1),
            timeLabel: '0:30',
            isYou: false,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('rank 4 shows numeral', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: LeaderboardRow(entry: entry(4), timeLabel: '0:40', isYou: true),
        ),
      ),
    );
    expect(find.text('4'), findsOneWidget);
  });
}
