import 'package:flutter/material.dart';

import '../../../core/dev_flags.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/next_puzzle_countdown.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import 'results_actions.dart';

/// The top of a daily result: which game, and when the next puzzle opens.
class ResultsTopBar extends StatelessWidget {
  const ResultsTopBar({super.key, required this.gameId, this.day});

  final String gameId;

  /// The run's day, so a run finished after midnight says the next puzzle
  /// is already out.
  final DateTime? day;

  static (IconData, Color) _iconFor(String gameId) => switch (gameId) {
    GameIds.pathWords => (AppIcons.path, ZipColors.sky),
    GameIds.sudoku => (AppIcons.grid, ZipColors.number),
    _ => (AppIcons.lightning, ZipColors.ember),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(gameId);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZipColors.inkSoft.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ZipColors.inkSoft.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                ResultsActions.titleFor(gameId),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _NextPuzzleLine(day: day)),
      ],
    );
  }
}

/// "New puzzle in 6h 12m", at the bar's end.
class _NextPuzzleLine extends StatelessWidget {
  const _NextPuzzleLine({this.day});

  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    final period = DevFlags.playPeriod;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppIcon(AppIcons.clock, size: 14, color: style?.color),
        const SizedBox(width: 5),
        Flexible(
          child: NextPuzzleCountdown(
            period: period,
            // The run's day is a date, which can't place a minute-long
            // debug period.
            periodOf: PlayPeriod.isSubDaily(period) ? null : day,
            style: style,
            textAlign: TextAlign.end,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
