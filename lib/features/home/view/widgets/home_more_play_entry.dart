import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/play_mode_route.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';

/// One compact row under the daily tiles that opens "More ways to play"
/// (archive, practice, bonus games). Home has no room for three entries on
/// a 360×640 screen.
class HomeMorePlayEntry extends StatelessWidget {
  const HomeMorePlayEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(layout.space(16));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push(moreWaysLocation),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: layout.space(12),
            vertical: layout.space(layout.isCompact ? 8 : 10),
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: ZipColors.glassBorder),
          ),
          child: Row(
            children: [
              Container(
                width: layout.space(34),
                height: layout.space(34),
                decoration: BoxDecoration(
                  color: ZipColors.skySoft,
                  borderRadius: BorderRadius.circular(layout.space(10)),
                  border: Border.all(
                    color: ZipColors.sky.withValues(alpha: 0.45),
                  ),
                ),
                child: AppIcon(
                  AppIcons.compass,
                  size: layout.space(20),
                  color: ZipColors.sky,
                ),
              ),
              SizedBox(width: layout.space(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.moreWaysTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      AppStrings.moreWaysEntryHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZipColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const AppIcon(AppIcons.chevronRight, color: ZipColors.inkSoft),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 320.ms, duration: 450.ms);
  }
}
