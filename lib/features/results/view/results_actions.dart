import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/usecases/next_uncleared_daily.dart';
import '../results_args.dart';

/// What to do after clearing a daily: play the next uncleared one, open the
/// full board, or go home. Each tap logs a `results_action`.
class ResultsActions extends StatelessWidget {
  const ResultsActions({super.key, required this.args});

  final ResultsArgs args;

  String get _gameId => args.gameId!;

  Future<void> _log(BuildContext context, String action) {
    return context.read<AnalyticsRepository>().logResultsAction(
      gameId: _gameId,
      action: action,
    );
  }

  static String _titleFor(String gameId) => switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTitle,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };

  @override
  Widget build(BuildContext context) {
    // The game routes open today's puzzle, so ask about today even when the
    // run just cleared was left open over midnight.
    final next = context.read<NextUnclearedDaily>()(
      justCleared: _gameId,
      playId: PlayPeriod.id(DateTime.now(), DevFlags.playPeriod),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          ZipPrimaryButton(
            label: AppStrings.playNextGame(_titleFor(next)),
            icon: Icons.play_arrow_rounded,
            onPressed: () async {
              await _log(context, 'play_next');
              if (!context.mounted) return;
              context.pushReplacement(NextUnclearedDaily.routeFor(next));
            },
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              AppStrings.perfectDay,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: ZipColors.success,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await _log(context, 'leaderboard');
            if (!context.mounted) return;
            context.go('/leaderboard?game=$_gameId');
          },
          icon: const Icon(Icons.leaderboard_rounded),
          label: const Text(AppStrings.seeFullLeaderboard),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () async {
            await _log(context, 'home');
            if (!context.mounted) return;
            context.go('/');
          },
          child: const Text(AppStrings.backHome),
        ),
      ],
    );
  }
}
