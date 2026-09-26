import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import 'zip_tutorial.dart';

class ZipHowToPlayButton extends StatelessWidget {
  const ZipHowToPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.zipHowToPlayTitle,
      onPressed: () async {
        try {
          await context.read<AnalyticsRepository>().logHowToPlayOpened(
            gameId: GameIds.zip,
          );
        } on ProviderNotFoundException {
          // Analytics may not be provided in focused widget tests.
        }
        if (!context.mounted) return;
        await ZipTutorial.show(context);
      },
      icon: const Icon(Icons.help_outline_rounded),
    );
  }
}
