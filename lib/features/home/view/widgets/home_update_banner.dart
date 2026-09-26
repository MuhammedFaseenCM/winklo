import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zip_ui.dart';

class HomeUpdateBanner extends StatelessWidget {
  const HomeUpdateBanner({
    super.key,
    required this.currentLabel,
    required this.requiredLabel,
    required this.onUpdate,
  });

  final String currentLabel;
  final String requiredLabel;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasVersions = currentLabel.isNotEmpty || requiredLabel.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C221D),
            ZipColors.wall,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZipColors.ember.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: ZipColors.ember.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ZipColors.emberSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ZipColors.ember.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: ZipColors.ember,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.updateAvailableTitle,
                    style: textTheme.titleMedium?.copyWith(
                      color: ZipColors.ember,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.updateAvailableBody,
              style: textTheme.bodyMedium?.copyWith(
                color: ZipColors.onInk,
                height: 1.35,
              ),
            ),
            if (hasVersions) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  AppStrings.updateVersionRow(currentLabel, requiredLabel),
                  style: textTheme.labelMedium?.copyWith(
                    color: ZipColors.inkSoft,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            ZipPrimaryButton(
              label: AppStrings.updateNow,
              icon: Icons.download_rounded,
              onPressed: onUpdate,
            ),
          ],
        ),
      ),
    );
  }
}
