import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import 'leaderboard_table.dart';

/// The Levels board's pinned line for a signed-in player who isn't on it:
/// "Clear a level to join", or, with stars already earned on this device,
/// "Replay a level to count your stars".
class LeaderboardLevelsNote extends StatelessWidget {
  const LeaderboardLevelsNote({super.key, required this.hasLocalStars});

  final bool hasLocalStars;

  @override
  Widget build(BuildContext context) {
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
