import 'package:flutter/material.dart';

import '../../../core/router/pop_or_go_home.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/game_ids.dart';

/// Title, icon and accent of a game on the hub and the archive.
class MorePlayGameStyle {
  const MorePlayGameStyle({
    required this.title,
    required this.icon,
    required this.accent,
    required this.accentSoft,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color accentSoft;

  static MorePlayGameStyle of(String gameId) => switch (gameId) {
    GameIds.pathWords => const MorePlayGameStyle(
      title: AppStrings.pathWordsTitle,
      icon: Icons.text_fields_rounded,
      accent: ZipColors.sky,
      accentSoft: ZipColors.skySoft,
    ),
    GameIds.sudoku => const MorePlayGameStyle(
      title: AppStrings.sudokuTitle,
      icon: Icons.grid_on_rounded,
      accent: ZipColors.success,
      accentSoft: ZipColors.successSoft,
    ),
    GameIds.wordMatch => const MorePlayGameStyle(
      title: AppStrings.wordMatch,
      icon: Icons.compare_arrows_rounded,
      accent: ZipColors.number,
      accentSoft: Color(0xFF3B1E2A),
    ),
    GameIds.categoryRace => const MorePlayGameStyle(
      title: AppStrings.categoryRace,
      icon: Icons.bolt_rounded,
      accent: Color(0xFFFBBF24),
      accentSoft: Color(0xFF3A3018),
    ),
    _ => const MorePlayGameStyle(
      title: AppStrings.zipTitle,
      icon: Icons.route_rounded,
      accent: ZipColors.ember,
      accentSoft: ZipColors.emberSoft,
    ),
  };
}

/// Back arrow and title at the top of a hub page.
class MorePlayHeader extends StatelessWidget {
  const MorePlayHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => popOrGoHome(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A section label with an optional line under it.
class MorePlaySectionTitle extends StatelessWidget {
  const MorePlaySectionTitle({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: ZipColors.inkSoft,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ZipColors.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable card: icon, title, one line and a chevron.
class MorePlayCard extends StatelessWidget {
  const MorePlayCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentSoft,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color accentSoft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: ZipColors.cardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ZipColors.glassBorder),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZipColors.inkSoft,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ZipColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
