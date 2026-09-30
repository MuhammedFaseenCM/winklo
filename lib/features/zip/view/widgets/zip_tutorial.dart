import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/game_tutorial_overlay.dart';
import '../../../../core/widgets/tutorial_mini_board.dart';
import '../../../../domain/entities/cell.dart';
import '../../../../domain/entities/wall.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/tutorial_repository.dart';

/// Canned Zip tutorial: start/finish → fill every cell → sped-up full path.
abstract final class ZipTutorial {
  static const size = 3;

  static final labels = <Cell, String>{
    const Cell(0, 0): '1',
    const Cell(0, 2): '2',
    const Cell(2, 2): '3',
  };

  static const walls = <Wall>[Wall(Cell(0, 1), Cell(1, 1))];

  static const solution = <Cell>[
    Cell(0, 0),
    Cell(0, 1),
    Cell(0, 2),
    Cell(1, 2),
    Cell(1, 1),
    Cell(1, 0),
    Cell(2, 0),
    Cell(2, 1),
    Cell(2, 2),
  ];

  static const captions = <String>[
    AppStrings.zipTutorialStart,
    AppStrings.zipTutorialFinish,
    AppStrings.zipTutorialFillEveryCell,
    AppStrings.zipTutorialWalls,
  ];

  static Future<void> show(BuildContext context, {bool isFirstRun = false}) {
    final repo = context.read<TutorialRepository>();
    AnalyticsRepository? analytics;
    try {
      analytics = context.read<AnalyticsRepository>();
    } on ProviderNotFoundException {
      analytics = null;
    }
    return GameTutorialOverlay.show(
      context: context,
      title: AppStrings.zipHowToPlayTitle,
      captions: captions,
      onDismissed: () async {
        if (isFirstRun) {
          await analytics?.logTutorialDismissed(gameId: GameIds.zip);
        }
        await repo.markSeen(GameIds.zip);
      },
      demoBuilder: (context, beat, beatT) {
        final pulse = 0.55 + 0.45 * math.sin(beatT * math.pi * 2);
        final start = const Cell(0, 0);
        final finish = const Cell(2, 2);
        final empties = {
          for (final cell in solution)
            if (!labels.containsKey(cell)) cell,
        };

        late final Set<Cell> highlights;
        late final double pathProgress;
        late final bool drawnFill;
        late final bool showFinger;
        var highlightWall = false;

        switch (beat) {
          case 0:
            highlights = {start};
            pathProgress = 0;
            drawnFill = false;
            showFinger = false;
          case 1:
            highlights = {finish};
            pathProgress = 0;
            drawnFill = false;
            showFinger = false;
          case 2:
            highlights = empties;
            pathProgress = 0;
            drawnFill = false;
            showFinger = false;
          default:
            highlights = const {};
            pathProgress = Curves.easeInOut.transform(beatT);
            drawnFill = true;
            showFinger = true;
            highlightWall = beatT > 0.15 && beatT < 0.55;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TutorialMiniBoard(
              size: size,
              labels: labels,
              walls: walls,
              path: solution,
              pathProgress: pathProgress,
              highlightCells: highlights,
              highlightPulse: pulse,
              drawnFill: drawnFill,
              showFinger: showFinger,
            ),
            if (highlightWall) ...[
              const SizedBox(height: 8),
              Icon(
                Icons.block,
                color: Colors.white.withValues(alpha: 0.7 * pulse),
                size: 18,
              ),
            ],
          ],
        );
      },
    );
  }

  static Future<void> maybeShow(BuildContext context) async {
    final repo = context.read<TutorialRepository>();
    if (await repo.hasSeen(GameIds.zip)) return;
    if (!context.mounted) return;
    final analytics = context.read<AnalyticsRepository>();
    await analytics.logTutorialShown(gameId: GameIds.zip);
    if (!context.mounted) return;
    await show(context, isFirstRun: true);
  }
}
