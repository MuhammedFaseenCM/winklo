import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/stats/game_stats.dart';

/// The six headline numbers of one game, three to a row.
class StatTiles extends StatelessWidget {
  const StatTiles({super.key, required this.stats});

  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    String time(int? seconds) => seconds == null
        ? AppStrings.statsNoValue
        : AppStrings.formatPlayTime(seconds);
    final share = stats.hintFreeShare;
    final tiles = [
      (AppStrings.statsClears, '${stats.clears}', AppIcons.checkCircle),
      (
        AppStrings.statsCurrentStreak,
        '${stats.currentStreak}',
        AppIcons.streak,
      ),
      (
        AppStrings.statsLongestStreak,
        '${stats.longestStreak}',
        AppIcons.trophy,
      ),
      (AppStrings.statsBestTime, time(stats.bestSeconds), AppIcons.lightning),
      (AppStrings.statsAverageTime, time(stats.averageSeconds), AppIcons.timer),
      (
        AppStrings.statsHintFree,
        share == null
            ? AppStrings.statsNoValue
            : AppStrings.statsPercent(share),
        AppIcons.noHints,
      ),
    ];
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: tiles[row * 3 + col].$1,
                    value: tiles[row * 3 + col].$2,
                    icon: tiles[row * 3 + col].$3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: ZipColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZipColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: 16, color: ZipColors.inkSoft),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: ZipColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
