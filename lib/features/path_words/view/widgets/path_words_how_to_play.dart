import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import 'path_words_tutorial.dart';

class PathWordsHowToPlayButton extends StatelessWidget {
  const PathWordsHowToPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.pathWordsHowToPlayTitle,
      onPressed: () async {
        try {
          await context.read<AnalyticsRepository>().logHowToPlayOpened(
            gameId: GameIds.pathWords,
          );
        } on ProviderNotFoundException {
          // Analytics may not be provided in focused widget tests.
        }
        if (!context.mounted) return;
        await PathWordsTutorial.show(context);
      },
      icon: const Icon(Icons.help_outline_rounded),
    );
  }
}
