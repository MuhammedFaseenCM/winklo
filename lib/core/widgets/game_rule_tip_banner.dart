import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Short coaching banner shown below the board (never drawn inside Flame).
class GameRuleTipBanner extends StatelessWidget {
  const GameRuleTipBanner({
    super.key,
    required this.message,
    this.accent = ZipColors.ember,
  });

  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ZipColors.wall,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AppIcon(AppIcons.hint, color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
