import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';

class SudokuHowToPlayButton extends StatelessWidget {
  const SudokuHowToPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.sudokuHowToPlayTitle,
      onPressed: () async {
        try {
          await context.read<AnalyticsRepository>().logHowToPlayOpened(
            gameId: GameIds.sudoku,
          );
        } on ProviderNotFoundException {
          // Analytics may not be provided in focused widget tests.
        }
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ZipColors.paper,
            title: const Text(AppStrings.sudokuHowToPlayTitle),
            content: const Text(AppStrings.sudokuHowToPlayBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(AppStrings.sudokuHowToPlayGotIt),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.help_outline_rounded),
    );
  }
}
