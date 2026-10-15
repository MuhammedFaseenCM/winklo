import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

/// "Today: Kitchen tools", shown only once the day is cleared. Nothing when
/// the day has no theme.
class PathWordsThemeLine extends StatelessWidget {
  const PathWordsThemeLine({super.key, required this.theme});

  final String? theme;

  @override
  Widget build(BuildContext context) {
    final value = theme;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: ZipColors.sky,
      fontWeight: FontWeight.w800,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 16, color: style?.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppStrings.pathWordsThemeReveal(value),
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
