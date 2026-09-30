import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/tutorial_mini_board.dart';
import 'package:winklo/domain/entities/cell.dart';

void main() {
  testWidgets('builds with startMarkers, lockedCells, completedPaths', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: TutorialMiniBoard(
            size: 3,
            labels: {
              const Cell(0, 0): 'C',
              const Cell(0, 1): 'A',
              const Cell(0, 2): 'T',
              const Cell(2, 0): 'R',
              const Cell(2, 1): 'U',
              const Cell(2, 2): 'N',
            },
            path: const [Cell(2, 0), Cell(2, 1), Cell(2, 2)],
            pathProgress: 0.5,
            drawnFill: true,
            startMarkers: {const Cell(0, 0), const Cell(2, 0)},
            lockedCells: {const Cell(0, 0), const Cell(0, 1), const Cell(0, 2)},
            completedPaths: const [
              (
                cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)],
                color: ZipColors.sky,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(TutorialMiniBoard), findsOneWidget);
  });
}
