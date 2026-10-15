import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';

/// The streak freezes banked for a game tile: a snowflake, with "×2" when
/// there are two. Nothing when there are none.
class HomeFreezeBadge extends StatelessWidget {
  const HomeFreezeBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final layout = AppLayout.of(context);
    final showCount = count > 1;
    return Tooltip(
      message: showCount
          ? AppStrings.streakFreezesReady(count)
          : AppStrings.streakFreezeReady,
      triggerMode: TooltipTriggerMode.tap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(showCount ? 7 : 5),
          vertical: layout.space(5),
        ),
        decoration: BoxDecoration(
          color: ZipColors.skySoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ZipColors.sky.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ac_unit_rounded,
              size: layout.space(13),
              color: ZipColors.sky,
            ),
            if (showCount) ...[
              SizedBox(width: layout.space(2)),
              Text(
                AppStrings.freezeCountLabel(count),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ZipColors.sky,
                  fontWeight: FontWeight.w800,
                  fontSize: layout.space(11),
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
