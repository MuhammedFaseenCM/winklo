import 'package:flutter/material.dart';

import '../../domain/entities/daily_special.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// "Weekend special": Saturday's and Sunday's harder dailies.
class WeekendSpecialBadge extends StatelessWidget {
  const WeekendSpecialBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ZipColors.ember,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ZipColors.emberSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZipColors.ember.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 12,
            color: style?.color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppStrings.weekendSpecial,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A game screen's title, with the [WeekendSpecialBadge] under it on a
/// weekend special.
class GameScreenTitle extends StatelessWidget {
  const GameScreenTitle({super.key, required this.title, this.special});

  final String title;

  /// The puzzle's `special` field.
  final String? special;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (!isWeekendSpecial(special)) return text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [text, const SizedBox(height: 2), const WeekendSpecialBadge()],
    );
  }
}
