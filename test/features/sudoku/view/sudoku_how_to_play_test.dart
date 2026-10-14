import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/features/sudoku/view/widgets/sudoku_how_to_play.dart';

class _MockTutorialRepository extends Mock implements TutorialRepository {}

void main() {
  late _MockTutorialRepository repo;
  final calls = <String>[];

  setUp(() {
    repo = _MockTutorialRepository();
    calls.clear();
    when(() => repo.markSeen(GameIds.sudoku)).thenAnswer((_) async {});
  });

  Future<void> pumpMaybeShow(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider<TutorialRepository>.value(
        value: repo,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => SudokuHowToPlay.maybeShow(
                  context,
                  onOpen: () => calls.add('open'),
                  onClose: () => calls.add('close'),
                ),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the first run and is marked seen on Got it', (
    tester,
  ) async {
    when(() => repo.hasSeen(GameIds.sudoku)).thenAnswer((_) async => false);

    await pumpMaybeShow(tester);

    expect(find.text(AppStrings.sudokuHowToPlayBody), findsOneWidget);
    expect(calls, ['open']); // the screen pauses the clock while reading
    await tester.tap(find.text(AppStrings.sudokuHowToPlayGotIt));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sudokuHowToPlayBody), findsNothing);
    expect(calls, ['open', 'close']);
    verify(() => repo.markSeen(GameIds.sudoku)).called(1);
  });

  testWidgets('stays closed once seen', (tester) async {
    when(() => repo.hasSeen(GameIds.sudoku)).thenAnswer((_) async => true);

    await pumpMaybeShow(tester);

    expect(find.text(AppStrings.sudokuHowToPlayBody), findsNothing);
    expect(calls, isEmpty);
    verifyNever(() => repo.markSeen(any()));
  });

  test('the rules describe free entry, not rejected digits', () {
    expect(AppStrings.sudokuHowToPlayBody, isNot(contains('rejected')));
  });
}
