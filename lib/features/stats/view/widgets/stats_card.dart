import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Glass card holding one stats section: a title row and a chart, or the
/// chart's empty state.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.emptyMessage,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Shown instead of [child] when non-null.
  final String? emptyMessage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = emptyMessage;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZipColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ZipColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          if (empty != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                empty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
            )
          else
            child,
        ],
      ),
    );
  }
}
