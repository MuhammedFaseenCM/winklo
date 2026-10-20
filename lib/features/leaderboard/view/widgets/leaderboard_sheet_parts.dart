import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';

/// The board and scope sheets' frame: a title over [children], scrolling
/// when the screen is short.
class LeaderboardSheetFrame extends StatelessWidget {
  const LeaderboardSheetFrame({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A choice in a picker sheet: [leading], then [label] over a quiet
/// [subtitle]; ember with a check when [selected].
class LeaderboardSheetOption extends StatelessWidget {
  const LeaderboardSheetOption({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? ZipColors.emberSoft
              : ZipColors.wall.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected
                  ? ZipColors.ember.withValues(alpha: 0.7)
                  : ZipColors.outlineQuiet.withValues(alpha: 0.7),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: selected
                                  ? ZipColors.ember
                                  : ZipColors.onInk,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium?.copyWith(
                                color: ZipColors.inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const AppIcon(
                        AppIcons.check,
                        size: 20,
                        color: ZipColors.ember,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
