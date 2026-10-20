import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_icons.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_podium.dart';
import 'package:winklo/features/leaderboard/view/widgets/medal_coin.dart';

LeaderboardEntry _e(int rank, {int? days}) => LeaderboardEntry(
  uid: 'u$rank',
  displayName: 'Player $rank',
  timeSeconds: 40 + rank * 5,
  updatedAt: DateTime.utc(2026, 10, 20),
  rank: rank,
  daysCleared: days,
  usedHints: rank == 1 ? false : null,
);

Future<List<LeaderboardEntry>> _pump(
  WidgetTester tester,
  List<LeaderboardEntry> entries, {
  LeaderboardPeriod period = LeaderboardPeriod.daily,
  String? currentUid,
  Key? youKey,
}) async {
  final tapped = <LeaderboardEntry>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: LeaderboardPodium(
            entries: entries,
            period: period,
            gameId: GameIds.zip,
            currentUid: currentUid,
            youKey: youKey,
            onTap: tapped.add,
          ),
        ),
      ),
    ),
  );
  return tapped;
}

void main() {
  testWidgets('first in the middle, second left, third right', (tester) async {
    await _pump(tester, [_e(1), _e(2), _e(3)]);
    final x1 = tester.getCenter(find.text('Player 1')).dx;
    expect(tester.getCenter(find.text('Player 2')).dx, lessThan(x1));
    expect(tester.getCenter(find.text('Player 3')).dx, greaterThan(x1));
    expect(find.byType(MedalCoin), findsNWidgets(3));
    expect(find.byIcon(AppIcons.crown), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
  });

  testWidgets('one player stays in the middle', (tester) async {
    await _pump(tester, [_e(1)]);
    expect(tester.getCenter(find.text('Player 1')).dx, closeTo(180, 12));
    expect(find.byType(MedalCoin), findsOneWidget);
  });

  testWidgets('the weekly podium shows days cleared', (tester) async {
    await _pump(tester, [
      _e(1, days: 7),
      _e(2, days: 6),
    ], period: LeaderboardPeriod.weekly);
    expect(find.text(AppStrings.leaderboardDaysShort(7)), findsOneWidget);
    expect(find.text(AppStrings.leaderboardDaysShort(6)), findsOneWidget);
  });

  testWidgets('your place says You and carries your key', (tester) async {
    final key = GlobalKey();
    await _pump(tester, [_e(1), _e(2)], currentUid: 'u2', youKey: key);
    expect(find.text(AppStrings.youLabel), findsOneWidget);
    expect(key.currentContext, isNotNull);
  });

  testWidgets('tapping a place reports its entry', (tester) async {
    final tapped = await _pump(tester, [_e(1), _e(2), _e(3)]);
    await tester.tap(find.text('Player 3'));
    expect(tapped.single.uid, 'u3');
  });

  testWidgets('each place is read as one button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_e(1)]);
    expect(
      find.bySemanticsLabel(
        RegExp(
          '^${RegExp.escape(AppStrings.leaderboardPodiumSemantics(1, 'Player 1', '0:45'))}',
        ),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
