import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/tutorial_repository.dart';

class SudokuHowToPlayButton extends StatelessWidget {
  const SudokuHowToPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.sudokuHowToPlayTitle,
      onPressed: () async {
        await _analytics(context)?.logHowToPlayOpened(gameId: GameIds.sudoku);
        if (!context.mounted) return;
        await SudokuHowToPlay.show(context);
      },
      icon: const AppIcon(AppIcons.help),
    );
  }
}

class SudokuHowToPlay {
  SudokuHowToPlay._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZipColors.paper,
        title: Text(AppStrings.sudokuHowToPlayTitle),
        content: Text(AppStrings.sudokuHowToPlayBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppStrings.sudokuHowToPlayGotIt),
          ),
        ],
      ),
    );
  }

  /// Opens the rules once, on a player's first Sudoku; Zip and Path Words do
  /// the same with their animated tutorials. [onOpen] and [onClose] run only
  /// when the dialog shows, so the screen can stop the clock while it's read.
  static Future<void> maybeShow(
    BuildContext context, {
    VoidCallback? onOpen,
    VoidCallback? onClose,
  }) async {
    final TutorialRepository repo;
    try {
      repo = context.read<TutorialRepository>();
    } on ProviderNotFoundException {
      return; // Not provided in focused widget tests.
    }
    if (await repo.hasSeen(GameIds.sudoku)) return;
    if (!context.mounted) return;
    final analytics = _analytics(context);
    await analytics?.logTutorialShown(gameId: GameIds.sudoku);
    if (!context.mounted) return;
    onOpen?.call();
    await show(context);
    onClose?.call();
    await analytics?.logTutorialDismissed(gameId: GameIds.sudoku);
    await repo.markSeen(GameIds.sudoku);
  }
}

AnalyticsRepository? _analytics(BuildContext context) {
  try {
    return context.read<AnalyticsRepository>();
  } on ProviderNotFoundException {
    return null; // Analytics may not be provided in focused widget tests.
  }
}
