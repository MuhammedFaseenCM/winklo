import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

/// The board pill ("Today ▾") and, when signed in, the scope pill
/// ("Everyone ▾"). Each opens its picker sheet.
class LeaderboardFilterRow extends StatelessWidget {
  const LeaderboardFilterRow({
    super.key,
    required this.boardIcon,
    required this.boardLabel,
    required this.onBoardTap,
    this.scopeIcon = Icons.public_rounded,
    this.scopeLabel,
    this.onScopeTap,
  });

  final IconData boardIcon;
  final String boardLabel;
  final VoidCallback onBoardTap;
  final IconData scopeIcon;

  /// Null hides the scope pill (signed out).
  final String? scopeLabel;
  final VoidCallback? onScopeTap;

  @override
  Widget build(BuildContext context) {
    final scope = scopeLabel;
    return Row(
      children: [
        _FilterPill(
          key: const Key('leaderboard_board_pill'),
          icon: boardIcon,
          label: boardLabel,
          semanticsLabel: AppStrings.leaderboardBoardPillLabel(boardLabel),
          onTap: onBoardTap,
        ),
        if (scope != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: _FilterPill(
              key: const Key('leaderboard_scope_pill'),
              icon: scopeIcon,
              label: scope,
              semanticsLabel: AppStrings.leaderboardScopePillLabel(scope),
              onTap: onScopeTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: ZipColors.wall.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ZipColors.outline.withValues(alpha: 0.8)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: ZipColors.ember),
                  const SizedBox(width: 6),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: ZipColors.onInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: ZipColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
