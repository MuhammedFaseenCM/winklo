import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';

/// "Includes +30s from hints" under a result's time, so a time that hints
/// pushed up doesn't read as a slow solve.
class HintPenaltyLine extends StatelessWidget {
  const HintPenaltyLine({super.key, required this.seconds});

  /// Seconds the run's hints added; already part of the time above.
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppIcons.hint, size: 14, color: style?.color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            AppStrings.resultsHintPenalty(seconds),
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ],
    );
  }
}
