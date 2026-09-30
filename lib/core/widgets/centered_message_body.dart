import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centered empty-state: optional title, message, and optional action.
class CenteredMessageBody extends StatelessWidget {
  const CenteredMessageBody({
    super.key,
    this.icon,
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.action,
    this.padding = const EdgeInsets.all(24),
    this.iconSpacing = 16,
    this.titleSpacing = 12,
    this.messageSpacing = 16,
    this.titleStyle,
    this.messageStyle,
    this.textAlign = TextAlign.center,
  });

  final Widget? icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final double iconSpacing;
  final double titleSpacing;
  final double messageSpacing;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedTitleStyle =
        titleStyle ??
        theme.textTheme.titleLarge?.copyWith(color: ZipColors.onInk);
    final resolvedMessageStyle =
        messageStyle ??
        theme.textTheme.bodyLarge?.copyWith(color: ZipColors.inkSoft);

    final Widget? resolvedAction =
        action ??
        (actionLabel != null && onAction != null
            ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
            : null);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              SizedBox(height: iconSpacing),
            ],
            if (title != null) ...[
              Text(title!, textAlign: textAlign, style: resolvedTitleStyle),
              SizedBox(height: titleSpacing),
            ],
            Text(message, textAlign: textAlign, style: resolvedMessageStyle),
            if (resolvedAction != null) ...[
              SizedBox(height: messageSpacing),
              resolvedAction,
            ],
          ],
        ),
      ),
    );
  }
}
