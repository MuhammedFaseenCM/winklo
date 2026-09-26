import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zip_ui.dart';

class HomeForceUpdateOverlay extends StatelessWidget {
  const HomeForceUpdateOverlay({
    super.key,
    required this.currentLabel,
    required this.requiredLabel,
    required this.onUpdate,
  });

  final String currentLabel;
  final String requiredLabel;
  final Future<void> Function() onUpdate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasVersions = currentLabel.isNotEmpty || requiredLabel.isNotEmpty;

    return Positioned.fill(
      child: BlockSemantics(
        blocking: true,
        child: Material(
          color: Colors.black.withValues(alpha: 0.65),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    decoration: BoxDecoration(
                      color: ZipColors.wall,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: ZipColors.ember.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                        BoxShadow(
                          color: ZipColors.ember.withValues(alpha: 0.2),
                          blurRadius: 36,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AppStrings.updateRequiredTitle,
                            style: textTheme.titleLarge?.copyWith(
                              color: ZipColors.ember,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.updateRequiredBody,
                            style: textTheme.bodyMedium?.copyWith(
                              color: ZipColors.onInk,
                            ),
                          ),
                          if (hasVersions) ...[
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.updateVersionRow(
                                currentLabel,
                                requiredLabel,
                              ),
                              style: textTheme.labelMedium?.copyWith(
                                color: ZipColors.inkSoft,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            AppStrings.updateCantSkip,
                            style: textTheme.labelMedium?.copyWith(
                              color: ZipColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ZipPrimaryButton(
                            label: AppStrings.updateNow,
                            onPressed: () {
                              unawaited(onUpdate());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
