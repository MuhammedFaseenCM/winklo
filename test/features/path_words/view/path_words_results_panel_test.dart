import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/path_words_clear_summary.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_definition_sheet.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_results_panel.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_theme_line.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('shows the theme, the words and the bonus count', (tester) async {
    await _pump(
      tester,
      const PathWordsResultsPanel(
        summary: PathWordsClearSummary(
          theme: 'Kitchen tools',
          words: ['ladle', 'kettle'],
          definitions: {'ladle': 'A deep spoon with a long handle'},
          bonusWords: ['stare', 'tears', 'rates'],
        ),
      ),
    );
    expect(find.text('Today: Kitchen tools'), findsOneWidget);
    expect(find.text('LADLE'), findsOneWidget);
    expect(find.text('KETTLE'), findsOneWidget);
    expect(find.text('3 bonus words'), findsOneWidget);
    expect(find.text(AppStrings.pathWordsTapForMeaning), findsOneWidget);
  });

  testWidgets(
    'tapping a word with a definition opens it; one without does nothing',
    (tester) async {
      await _pump(
        tester,
        const PathWordsResultsPanel(
          summary: PathWordsClearSummary(
            words: ['ladle', 'kettle'],
            definitions: {'ladle': 'A deep spoon with a long handle'},
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('pathWordsResultWord_ladle')),
          matching: find.byType(ActionChip),
        ),
        findsNothing,
      );
      expect(
        tester.widget(find.byKey(const Key('pathWordsResultWord_ladle'))),
        isA<ActionChip>(),
      );
      expect(
        tester.widget(find.byKey(const Key('pathWordsResultWord_kettle'))),
        isA<Chip>(),
      );

      await tester.tap(find.byKey(const Key('pathWordsResultWord_kettle')));
      await tester.pumpAndSettle();
      expect(find.byType(PathWordsDefinitionSheet), findsNothing);

      await tester.tap(find.byKey(const Key('pathWordsResultWord_ladle')));
      await tester.pumpAndSettle();
      expect(find.byType(PathWordsDefinitionSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PathWordsDefinitionSheet),
          matching: find.text('LADLE'),
        ),
        findsOneWidget,
      );
      expect(find.text('A deep spoon with a long handle'), findsOneWidget);
    },
  );

  testWidgets('a word with a meaning is a button screen readers can tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const PathWordsResultsPanel(
        summary: PathWordsClearSummary(
          words: ['ladle'],
          definitions: {'ladle': 'A deep spoon with a long handle'},
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('pathWordsResultWord_ladle'))),
      isSemantics(
        label: 'LADLE, tap for its meaning',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('leaves out what the day does not have', (tester) async {
    await _pump(
      tester,
      const PathWordsResultsPanel(
        summary: PathWordsClearSummary(words: ['ladle']),
      ),
    );
    expect(find.textContaining('Today:'), findsNothing);
    expect(find.textContaining('bonus word'), findsNothing);
    expect(find.text(AppStrings.pathWordsTapForMeaning), findsNothing);
  });

  testWidgets('one bonus word is singular', (tester) async {
    await _pump(
      tester,
      const PathWordsResultsPanel(
        summary: PathWordsClearSummary(words: ['ladle'], bonusWords: ['stare']),
      ),
    );
    expect(find.text('1 bonus word'), findsOneWidget);
  });

  testWidgets('the theme line is empty without a theme', (tester) async {
    await _pump(tester, const PathWordsThemeLine(theme: null));
    expect(find.byType(Text), findsNothing);
    await _pump(tester, const PathWordsThemeLine(theme: 'Pets'));
    expect(find.text('Today: Pets'), findsOneWidget);
  });
}
