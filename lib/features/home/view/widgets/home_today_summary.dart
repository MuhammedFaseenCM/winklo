import 'package:flutter/material.dart';

import '../../../../core/dev_flags.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/today_summary.dart';

/// Above the Home tiles: "2 of 3 cleared · 3:41 total", with a "Perfect day"
/// badge once all three are done. Nothing shows before the first clear.
class HomeTodaySummary extends StatelessWidget {
  const HomeTodaySummary({super.key, required this.summary});

  final TodaySummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    // The Zip-only debug build hides the other games' tiles.
    if (summary == null || DevFlags.zipOnlyTesting) {
      return const SizedBox.shrink();
    }
    final layout = AppLayout.of(context);
    final textTheme = Theme.of(context).textTheme;
    final perfect = summary.isPerfectDay;
    final text = AppStrings.homeTodaySummary(
      cleared: summary.cleared,
      total: summary.total,
      totalSeconds: summary.totalSeconds,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: layout.tileGap),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: layout.space(14),
          vertical: layout.space(10),
        ),
        decoration: BoxDecoration(
          gradient: ZipColors.cardGradient,
          borderRadius: BorderRadius.circular(layout.space(16)),
          border: Border.all(
            color: perfect
                ? ZipColors.ember.withValues(alpha: 0.45)
                : ZipColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: perfect ? ZipColors.ember : ZipColors.success,
              size: 20,
            ),
            SizedBox(width: layout.space(10)),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w700,
                  fontSize: layout.isCompact ? 13 : 14,
                ),
              ),
            ),
            if (perfect) ...[
              SizedBox(width: layout.space(8)),
              const _PerfectDayBadge(),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerfectDayBadge extends StatelessWidget {
  const _PerfectDayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZipColors.ember.withValues(alpha: 0.28),
            ZipColors.ember.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZipColors.ember.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: ZipColors.ember, size: 14),
          const SizedBox(width: 4),
          Text(
            AppStrings.homePerfectDayBadge,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ZipColors.ember,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
