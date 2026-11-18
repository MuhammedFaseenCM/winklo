import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/player_card_sheet.dart';

final _levelsEntry = LeaderboardEntry(
  uid: 'p1',
  displayName: 'Ada',
  timeSeconds: 2531,
  updatedAt: DateTime.utc(2026, 11, 18),
  rank: 3,
  stars: 120,
  levelsCleared: 40,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    LeaderboardEntry entry,
    LeaderboardPeriod period,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PlayerCard(entry: entry, gameId: GameIds.zip, period: period),
        ),
      ),
    );
  }

  testWidgets('a Levels row shows stars, levels and total time', (
    tester,
  ) async {
    await pumpCard(tester, _levelsEntry, LeaderboardPeriod.levels);
    expect(find.text(AppStrings.playerCardStars), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(AppStrings.playerCardLevels), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text(AppStrings.playerCardTotalTime), findsOneWidget);
    expect(find.text('42:11'), findsOneWidget);
    expect(find.text(AppStrings.playerCardTime), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a daily row shows only its time', (tester) async {
    await pumpCard(tester, _levelsEntry, LeaderboardPeriod.daily);
    expect(find.text(AppStrings.playerCardTime), findsOneWidget);
    expect(find.text(AppStrings.playerCardStars), findsNothing);
    expect(find.text(AppStrings.playerCardLevels), findsNothing);
    expect(find.text(AppStrings.playerCardTotalTime), findsNothing);
  });
}
