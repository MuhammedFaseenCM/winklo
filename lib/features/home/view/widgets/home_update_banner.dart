import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/zip_ui.dart';

class HomeUpdateBanner extends StatelessWidget {
  const HomeUpdateBanner({
    super.key,
    required this.currentLabel,
    required this.requiredLabel,
    required this.onUpdate,
    this.updateLabel,
    this.updateIcon = AppIcons.download,
    this.onSnooze,
  });

  final String currentLabel;
  final String requiredLabel;

  /// Null disables the button (while an update downloads).
  final VoidCallback? onUpdate;

  /// Null reads [AppStrings.updateNow].
  final String? updateLabel;
  final IconData updateIcon;

  /// Shows a close button that hides the banner for a while.
  final VoidCallback? onSnooze;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasVersions = currentLabel.isNotEmpty || requiredLabel.isNotEmpty;
    final snooze = onSnooze;

    // Compact: on a busy day it sits above the habit cards and today's
    // summary, and the first daily tile should still show on a 360×640 phone.
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C221D), ZipColors.wall],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZipColors.ember.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ZipColors.ember.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 12, snooze == null ? 14 : 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ZipColors.emberSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ZipColors.ember.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const AppIcon(
                    AppIcons.update,
                    color: ZipColors.ember,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.updateAvailableTitle,
                        style: textTheme.titleSmall?.copyWith(
                          color: ZipColors.ember,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.updateAvailableBody,
                        style: textTheme.bodySmall?.copyWith(
                          color: ZipColors.onInk,
                          height: 1.3,
                        ),
                      ),
                      if (hasVersions) ...[
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.updateVersionRow(
                            currentLabel,
                            requiredLabel,
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: ZipColors.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (snooze != null)
                  IconButton(
                    tooltip: AppStrings.updateSnooze,
                    onPressed: snooze,
                    visualDensity: VisualDensity.compact,
                    color: ZipColors.inkSoft,
                    icon: const AppIcon(AppIcons.close, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.only(right: snooze == null ? 0 : 10),
              child: ZipPrimaryButton(
                label: updateLabel ?? AppStrings.updateNow,
                icon: updateIcon,
                compact: true,
                onPressed: onUpdate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
