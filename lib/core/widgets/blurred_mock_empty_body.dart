import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'centered_message_body.dart';

/// Signed-out tease: blurred mock UI + dim scrim + centered message/CTA.
class BlurredMockEmptyBody extends StatelessWidget {
  const BlurredMockEmptyBody({
    super.key,
    required this.background,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.action,
    this.blurSigma = 10,
    this.scrimColor,
  });

  final Widget background;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final double blurSigma;
  final Color? scrimColor;

  @override
  Widget build(BuildContext context) {
    final resolvedScrim = scrimColor ?? ZipColors.ink.withValues(alpha: 0.45);

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: background,
          ),
        ),
        ColoredBox(color: resolvedScrim),
        CenteredMessageBody(
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          action: action,
        ),
      ],
    );
  }
}
