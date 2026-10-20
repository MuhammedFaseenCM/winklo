import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/path_words_clear_summary.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/features/results/logic/result_tiles.dart';
import 'package:winklo/features/results/view/result_tiles_row.dart';
import 'package:winklo/features/results/view/results_board_card.dart';
import 'package:winklo/features/results/view/results_hero.dart';
import 'package:winklo/features/results/view/results_top_bar.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

/// The pieces of the daily Results page, one at a time.
void main() {
  testWidgets('the top bar names the game and counts down', (tester) async {
    await tester.pumpWidget(
      _app(ResultsTopBar(gameId: GameIds.pathWords, day: DateTime.now())),
    );
    expect(find.text(AppStrings.pathWordsTitle), findsOneWidget);
    expect(find.textContaining('New puzzle in'), findsOneWidget);
  });

  testWidgets('the rank badge reads its rank and total', (tester) async {
    await tester.pumpWidget(_app(const ResultsRankBadge(rank: 14, total: 18)));
    expect(find.text('#14'), findsOneWidget);
    expect(find.text(AppStrings.resultsRankOfToday(18)), findsOneWidget);
    expect(
      find.bySemanticsLabel(AppStrings.resultsRankSemantics(14, 18)),
      findsOneWidget,
    );
  });

  testWidgets('a loading badge is an empty outline', (tester) async {
    await tester.pumpWidget(_app(const ResultsRankBadge()));
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('the hero lands on the time', (tester) async {
    await tester.pumpWidget(
      _app(const ResultsHero(title: 'Puzzle cleared!', timeSeconds: 107)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Puzzle cleared!'), findsOneWidget);
    expect(find.text(AppStrings.formatPlayTime(107)), findsOneWidget);
  });

  testWidgets('tiles show their titles and captions', (tester) async {
    await tester.pumpWidget(
      _app(
        const ResultTilesRow(
          tiles: [
            StreakTile(days: 6, longest: 11),
            PersonalBestTile(),
            HintTimeTile(20),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.streakLabel(6)), findsOneWidget);
    expect(find.text(AppStrings.longestStreakLabel(11)), findsOneWidget);
    expect(find.text(AppStrings.newPersonalBest), findsOneWidget);
    expect(find.text(AppStrings.resultsHintTimeTile(20)), findsOneWidget);
    expect(find.text(AppStrings.resultsFromHints), findsOneWidget);
  });

  testWidgets('no tiles, no row', (tester) async {
    await tester.pumpWidget(_app(const ResultTilesRow(tiles: [])));
    expect(find.byType(IntrinsicHeight), findsNothing);
  });

  testWidgets('Path Words cards switch between the board and the words', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          height: 400,
          child: ResultsBoardCard(
            board: Text('the board'),
            pathWords: PathWordsClearSummary(
              theme: 'Kitchen tools',
              words: ['ladle', 'kettle'],
              bonusWords: ['tale'],
            ),
          ),
        ),
      ),
    );
    expect(find.text('the board'), findsOneWidget);
    expect(find.text('LADLE'), findsNothing);

    await tester.tap(find.text(AppStrings.resultsWordsTab(2)));
    await tester.pumpAndSettle();
    expect(find.text('the board'), findsNothing);
    expect(find.text('LADLE'), findsOneWidget);
    expect(find.text(AppStrings.pathWordsBonusCount(1)), findsOneWidget);

    await tester.tap(find.text(AppStrings.resultsBoardTab));
    await tester.pumpAndSettle();
    expect(find.text('the board'), findsOneWidget);
    expect(find.text('LADLE'), findsNothing);
  });

  testWidgets('other games get no switch', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          height: 300,
          child: ResultsBoardCard(board: Text('the board')),
        ),
      ),
    );
    expect(find.text('the board'), findsOneWidget);
    expect(find.text(AppStrings.resultsBoardTab), findsNothing);
  });
}
