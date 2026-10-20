import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../logic/result_tiles.dart';

/// Up to three equal tiles under the time; nothing when [tiles] is empty.
class ResultTilesRow extends StatelessWidget {
  const ResultTilesRow({super.key, required this.tiles, this.compact = false});

  final List<ResultTile> tiles;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _Tile(tile: tiles[i], compact: compact)
                  .animate()
                  .fadeIn(delay: (520 + 60 * i).ms, duration: 350.ms)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    curve: Curves.easeOutBack,
                    duration: 420.ms,
                    delay: (520 + 60 * i).ms,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.compact});

  final ResultTile tile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color, title, caption) = switch (tile) {
      StreakTile(:final days, :final longest) => (
        AppIcons.streak,
        ZipColors.ember,
        AppStrings.streakLabel(days),
        longest == null ? null : AppStrings.longestStreakLabel(longest),
      ),
      PersonalBestTile() => (
        AppIcons.star,
        ZipColors.success,
        AppStrings.newPersonalBest,
        null,
      ),
      HintTimeTile(:final seconds) => (
        AppIcons.hint,
        ZipColors.onInk.withValues(alpha: 0.8),
        AppStrings.resultsHintTimeTile(seconds),
        AppStrings.resultsFromHints,
      ),
      HintFreeTile() => (
        AppIcons.noHints,
        ZipColors.teal,
        AppStrings.statsHintFree,
        null,
      ),
      FlawlessTile() => (
        AppIcons.flawless,
        ZipColors.sky,
        AppStrings.leaderboardNoMistakesChip,
        null,
      ),
      BonusWordsTile(:final count) => (
        AppIcons.sparkle,
        ZipColors.sky,
        AppStrings.pathWordsBonusCount(count),
        null,
      ),
    };
    return MergeSemantics(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8, horizontal: 6),
        decoration: BoxDecoration(
          color: ZipColors.inkSoft.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZipColors.inkSoft.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: compact ? 16 : 18, color: color),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelLarge?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                height: 1.2,
              ),
            ),
            if (caption != null)
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: ZipColors.inkSoft,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
