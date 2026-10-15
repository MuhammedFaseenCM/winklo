import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/league.dart';

/// Whose times the board shows: everyone, or one of my leagues.
class LeaderboardScopeBar extends StatelessWidget {
  const LeaderboardScopeBar({
    super.key,
    required this.leagues,
    required this.selectedLeagueId,
    required this.onSelected,
  });

  final List<League> leagues;

  /// Null is everyone.
  final String? selectedLeagueId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        key: const Key('leaderboard_scope_bar'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _ScopeChip(
            label: AppStrings.leaderboardScopeEveryone,
            icon: Icons.public_rounded,
            selected: selectedLeagueId == null,
            onTap: () => onSelected(null),
          ),
          for (final league in leagues) ...[
            const SizedBox(width: 6),
            _ScopeChip(
              label: league.name,
              icon: Icons.group_rounded,
              selected: league.id == selectedLeagueId,
              onTap: () => onSelected(league.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZipColors.ember : ZipColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? ZipColors.emberSoft
            : ZipColors.wall.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? ZipColors.ember.withValues(alpha: 0.6)
                : ZipColors.outlineQuiet.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
