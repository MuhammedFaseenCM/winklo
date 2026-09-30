import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/game_tutorial_overlay.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/tutorial_repository.dart';
import 'package:winklo/features/zip/view/widgets/zip_tutorial.dart';

class _MockTutorialRepository extends Mock implements TutorialRepository {}

void main() {
  Future<void> pumpOpenButton(WidgetTester tester, TutorialRepository repo) {
    return tester.pumpWidget(
      RepositoryProvider<TutorialRepository>.value(
        value: repo,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => ZipTutorial.show(context),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('ZipTutorial.show marks seen on Skip', (tester) async {
    final repo = _MockTutorialRepository();
    when(() => repo.markSeen(GameIds.zip)).thenAnswer((_) async {});

    await pumpOpenButton(tester, repo);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GameTutorialOverlay), findsOneWidget);
    expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
    expect(find.text(AppStrings.tutorialSkip), findsOneWidget);

    await tester.tap(find.text(AppStrings.tutorialSkip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(() => repo.markSeen(GameIds.zip)).called(1);
  });

  testWidgets('ZipTutorial exposes all four captions via Next', (tester) async {
    final repo = _MockTutorialRepository();
    when(() => repo.markSeen(GameIds.zip)).thenAnswer((_) async {});

    await pumpOpenButton(tester, repo);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final expected = [
      AppStrings.zipTutorialStart,
      AppStrings.zipTutorialFinish,
      AppStrings.zipTutorialFillEveryCell,
      AppStrings.zipTutorialWalls,
    ];
    for (var i = 0; i < expected.length; i++) {
      expect(find.text(expected[i]), findsOneWidget);
      if (i < expected.length - 1) {
        await tester.tap(find.text(AppStrings.tutorialNext));
        await tester.pump();
      }
    }
    expect(find.text(AppStrings.tutorialGotIt), findsOneWidget);
    await tester.tap(find.text(AppStrings.tutorialGotIt));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => repo.markSeen(GameIds.zip)).called(1);
  });
}
