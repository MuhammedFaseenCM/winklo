import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/repositories/level_progress_repository.dart';
import 'leaderboard_table.dart';

/// The Levels board's pinned line for a signed-in player who isn't on it:
/// "Clear a level to join", or, with stars already earned on this device,
/// "Replay a level to count your stars". The local stars are those of
/// [gameId], the game whose Levels board is showing.
class LeaderboardLevelsNote extends StatelessWidget {
  const LeaderboardLevelsNote({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    // A test or a build without the repository just has no local stars.
    final hasLocalStars =
        (context
                .read<LevelProgressRepository?>()
                ?.progress(gameId)
                .totalStars ??
            0) >
        0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ZipColors.wall,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ZipColors.ember.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const AppIcon(AppIcons.levels, color: ZipColors.ember, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasLocalStars
                      ? AppStrings.leaderboardLevelsReplay
                      : AppStrings.leaderboardLevelsJoin,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
