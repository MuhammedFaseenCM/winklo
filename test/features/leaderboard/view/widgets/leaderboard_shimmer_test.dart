import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_shimmer.dart';

void main() {
  testWidgets('LeaderboardShimmer builds row-shaped placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: LeaderboardShimmer(rowCount: 3)),
      ),
    );

    expect(find.byType(AppShimmerCircle), findsNWidgets(3));
    expect(find.byType(AppShimmerBox), findsWidgets);
  });
}
