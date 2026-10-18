import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/league.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_scope_sheet.dart';

const _family = League(
  id: 'L1',
  name: 'Family',
  ownerUid: 'u1',
  code: 'ABC234',
  memberUids: ['u1', 'u2', 'u3'],
);

void main() {
  /// Opens the sheet, then taps [tap] if given. Returns the pick.
  Future<LeaderboardScopeChoice?> open(
    WidgetTester tester, {
    List<League> leagues = const [_family],
    String? selected,
    Finder? tap,
  }) async {
    LeaderboardScopeChoice? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showLeaderboardScopeSheet(
                  context,
                  leagues: leagues,
                  selectedLeagueId: selected,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (tap != null) {
      await tester.tap(tap);
      await tester.pumpAndSettle();
    }
    return picked;
  }

  testWidgets('lists Everyone and my leagues with their sizes', (tester) async {
    await open(tester);
    expect(find.text(AppStrings.leaderboardScopeSheetTitle), findsOneWidget);
    expect(find.text(AppStrings.leaderboardScopeEveryone), findsOneWidget);
    expect(find.text(AppStrings.leaderboardTop50), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text(AppStrings.leaderboardLeaguePlayers(3)), findsOneWidget);
    expect(find.text(AppStrings.leaderboardManageLeagues), findsOneWidget);
  });

  testWidgets('without leagues it offers to create or join one', (
    tester,
  ) async {
    await open(tester, leagues: const []);
    expect(find.text(AppStrings.leaderboardCreateOrJoinLeague), findsOneWidget);
    expect(find.text(AppStrings.leaderboardManageLeagues), findsNothing);
  });

  testWidgets('picking a league returns it', (tester) async {
    final choice = await open(tester, tap: find.text('Family'));
    expect(choice?.leagueId, 'L1');
    expect(choice?.manageLeagues, isFalse);
  });

  testWidgets('picking Everyone returns no league', (tester) async {
    final choice = await open(
      tester,
      selected: 'L1',
      tap: find.text(AppStrings.leaderboardScopeEveryone),
    );
    expect(choice, isNotNull);
    expect(choice?.leagueId, isNull);
    expect(choice?.manageLeagues, isFalse);
  });

  testWidgets('the leagues button asks for the leagues screen', (tester) async {
    final choice = await open(
      tester,
      tap: find.text(AppStrings.leaderboardManageLeagues),
    );
    expect(choice?.manageLeagues, isTrue);
  });

  testWidgets('dismissing picks nothing', (tester) async {
    final choice = await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(choice, isNull);
    expect(find.text(AppStrings.leaderboardScopeSheetTitle), findsNothing);
  });
}
