import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/widgets/game_tutorial_overlay.dart';
import 'package:winklo/core/widgets/tutorial_mini_board.dart';
import 'package:winklo/domain/entities/cell.dart';

void main() {
  Widget harness({
    required List<String> captions,
    required VoidCallback onGotIt,
    Duration beatDuration = const Duration(milliseconds: 400),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GameTutorialOverlay(
          title: AppStrings.zipHowToPlayTitle,
          captions: captions,
          beatDuration: beatDuration,
          onGotIt: onGotIt,
          demoBuilder: (context, beat, beatT) {
            return TutorialMiniBoard(
              size: 2,
              labels: {const Cell(0, 0): '1', const Cell(1, 1): '2'},
              path: const [Cell(0, 0), Cell(0, 1), Cell(1, 1)],
              pathProgress: beat == 0 ? 0 : beatT,
              drawnFill: beat > 0,
            );
          },
        ),
      ),
    );
  }

  testWidgets('stays on step until Next; last step shows Got it only', (
    tester,
  ) async {
    var gotIt = false;
    await tester.pumpWidget(
      harness(
        captions: const [
          AppStrings.zipTutorialStart,
          AppStrings.zipTutorialFinish,
        ],
        onGotIt: () => gotIt = true,
      ),
    );

    expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
    expect(find.text(AppStrings.tutorialNext), findsOneWidget);
    expect(find.text(AppStrings.tutorialSkip), findsOneWidget);
    expect(find.text(AppStrings.tutorialGotIt), findsNothing);

    // Demo may loop, but step must not auto-advance.
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
    expect(find.text(AppStrings.zipTutorialFinish), findsNothing);

    await tester.tap(find.text(AppStrings.tutorialNext));
    await tester.pump();
    expect(find.text(AppStrings.zipTutorialFinish), findsOneWidget);
    expect(find.text(AppStrings.tutorialGotIt), findsOneWidget);
    expect(find.text(AppStrings.tutorialNext), findsNothing);
    expect(find.text(AppStrings.tutorialSkip), findsNothing);

    await tester.tap(find.text(AppStrings.tutorialGotIt));
    await tester.pump();
    expect(gotIt, isTrue);
  });

  testWidgets('Next advances; Skip dismisses', (tester) async {
    var gotIt = false;
    await tester.pumpWidget(
      harness(
        captions: const [
          AppStrings.zipTutorialStart,
          AppStrings.zipTutorialFinish,
          AppStrings.zipTutorialFillEveryCell,
        ],
        onGotIt: () => gotIt = true,
        beatDuration: const Duration(seconds: 10),
      ),
    );

    expect(find.text(AppStrings.zipTutorialStart), findsOneWidget);
    await tester.tap(find.text(AppStrings.tutorialNext));
    await tester.pump();
    expect(find.text(AppStrings.zipTutorialFinish), findsOneWidget);

    await tester.tap(find.text(AppStrings.tutorialSkip));
    await tester.pump();
    expect(gotIt, isTrue);
  });
}
