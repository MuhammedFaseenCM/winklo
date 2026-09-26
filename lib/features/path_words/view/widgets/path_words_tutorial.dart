import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/game_tutorial_overlay.dart';
import '../../../../core/widgets/tutorial_mini_board.dart';
import '../../../../domain/entities/cell.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/tutorial_repository.dart';

/// Canned Path Words tutorial: match list → every word → fill every cell.
abstract final class PathWordsTutorial {
  static const size = 3;

  static final labels = <Cell, String>{
    const Cell(0, 0): 'C',
    const Cell(0, 1): 'A',
    const Cell(0, 2): 'T',
    const Cell(1, 0): 'D',
    const Cell(1, 1): 'O',
    const Cell(1, 2): 'G',
    const Cell(2, 0): 'R',
    const Cell(2, 1): 'U',
    const Cell(2, 2): 'N',
  };

  static const wordPath = <Cell>[Cell(0, 0), Cell(0, 1), Cell(0, 2)];

  static const secondWordPath = <Cell>[Cell(1, 0), Cell(1, 1), Cell(1, 2)];

  static const thirdWordPath = <Cell>[Cell(2, 0), Cell(2, 1), Cell(2, 2)];

  static const word = 'CAT';

  static const secondWord = 'DOG';

  static const thirdWord = 'RUN';

  static const captions = <String>[
    AppStrings.pathWordsTutorialMatchList,
    AppStrings.pathWordsTutorialFindEveryWord,
    AppStrings.pathWordsTutorialFillEveryCell,
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
      title: AppStrings.pathWordsHowToPlayTitle,
      captions: captions,
      onDismissed: () async {
        if (isFirstRun) {
          await analytics?.logTutorialDismissed(gameId: GameIds.pathWords);
        }
        await repo.markSeen(GameIds.pathWords);
      },
      demoBuilder: (context, beat, beatT) {
        late final List<Cell> path;
        late final double pathProgress;
        late final bool showFinger;
        late final bool catComplete;
        late final bool dogComplete;
        late final bool runComplete;
        late final Set<Cell> lockedCells;
        late final List<TutorialCompletedPath> completedPaths;
        late final Set<Cell> highlightCells;

        final pulse = 0.55 + 0.45 * math.sin(beatT * math.pi * 2);

        switch (beat) {
          case 0:
            // Match a word on the list — draw CAT.
            path = wordPath;
            pathProgress = Curves.easeInOut.transform(beatT);
            showFinger = pathProgress < 0.98;
            catComplete = pathProgress >= 0.98;
            dogComplete = false;
            runComplete = false;
            lockedCells = const {};
            completedPaths = const [];
            highlightCells = catComplete ? wordPath.toSet() : const {};
          case 1:
            // Find every word — finish DOG with CAT done.
            path = secondWordPath;
            pathProgress = Curves.easeInOut.transform(beatT);
            showFinger = pathProgress < 0.98;
            catComplete = true;
            dogComplete = pathProgress >= 0.98;
            runComplete = false;
            lockedCells = wordPath.toSet();
            completedPaths = const [(cells: wordPath, color: ZipColors.sky)];
            highlightCells = dogComplete ? secondWordPath.toSet() : const {};
          default:
            // Every cell should fill — all three words complete.
            path = const [];
            pathProgress = 0;
            showFinger = false;
            catComplete = true;
            dogComplete = true;
            runComplete = true;
            lockedCells = {...wordPath, ...secondWordPath, ...thirdWordPath};
            completedPaths = const [
              (cells: wordPath, color: ZipColors.sky),
              (cells: secondWordPath, color: ZipColors.ember),
              (cells: thirdWordPath, color: ZipColors.success),
            ];
            highlightCells = {...wordPath, ...secondWordPath, ...thirdWordPath};
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: TutorialMiniBoard(
                size: size,
                labels: labels,
                path: path,
                pathProgress: pathProgress,
                drawnFill: path.isNotEmpty,
                pathColor: ZipColors.sky,
                showFinger: showFinger,
                fingerLifted: false,
                highlightCells: highlightCells,
                highlightPulse: highlightCells.isEmpty ? 0 : pulse,
                lockedCells: lockedCells,
                completedPaths: completedPaths,
              ),
            ),
            const SizedBox(height: 12),
            _MiniWordList(
              catComplete: catComplete,
              dogComplete: dogComplete,
              runComplete: runComplete,
              pulse: pulse,
            ),
          ],
        );
      },
    );
  }

  static Future<void> maybeShow(BuildContext context) async {
    final repo = context.read<TutorialRepository>();
    if (await repo.hasSeen(GameIds.pathWords)) return;
    if (!context.mounted) return;
    final analytics = context.read<AnalyticsRepository>();
    await analytics.logTutorialShown(gameId: GameIds.pathWords);
    if (!context.mounted) return;
    await show(context, isFirstRun: true);
  }
}

class _MiniWordList extends StatelessWidget {
  const _MiniWordList({
    required this.catComplete,
    required this.dogComplete,
    required this.runComplete,
    required this.pulse,
  });

  final bool catComplete;
  final bool dogComplete;
  final bool runComplete;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniWordListRow(
          label: catComplete ? PathWordsTutorial.word : '• • •',
          complete: catComplete,
          pulse: pulse,
        ),
        const SizedBox(height: 8),
        _MiniWordListRow(
          label: dogComplete ? PathWordsTutorial.secondWord : '• • •',
          complete: dogComplete,
          pulse: pulse,
        ),
        const SizedBox(height: 8),
        _MiniWordListRow(
          label: runComplete ? PathWordsTutorial.thirdWord : '• • •',
          complete: runComplete,
          pulse: pulse,
        ),
      ],
    );
  }
}

class _MiniWordListRow extends StatelessWidget {
  const _MiniWordListRow({
    required this.label,
    required this.complete,
    required this.pulse,
  });

  final String label;
  final bool complete;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: complete ? ZipColors.skySoft : ZipColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: complete
              ? ZipColors.sky.withValues(alpha: 0.5 + 0.4 * pulse)
              : ZipColors.outlineQuiet,
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: complete ? ZipColors.sky : ZipColors.inkSoft,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w700,
              letterSpacing: complete ? 2 : 4,
            ),
          ),
        ],
      ),
    );
  }
}
