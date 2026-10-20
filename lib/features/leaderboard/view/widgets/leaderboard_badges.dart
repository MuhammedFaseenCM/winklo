import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../logic/board_layout.dart';

IconData _icon(LeaderboardBadge badge) => switch (badge) {
  LeaderboardBadge.noHints => AppIcons.noHints,
  LeaderboardBadge.flawless => AppIcons.flawless,
  LeaderboardBadge.streak => AppIcons.streak,
};

Color _color(LeaderboardBadge badge) => switch (badge) {
  LeaderboardBadge.noHints => const Color(0xFF7EE0C3),
  LeaderboardBadge.flawless => const Color(0xFF9EC0FF),
  LeaderboardBadge.streak => const Color(0xFFFFC27A),
};

String _keyLabel(LeaderboardBadge badge) => switch (badge) {
  LeaderboardBadge.noHints => AppStrings.leaderboardNoHintChip,
  LeaderboardBadge.flawless => AppStrings.leaderboardNoMistakesChip,
  LeaderboardBadge.streak => AppStrings.leaderboardKeyStreak,
};

/// What [badge] means for [entry], read aloud.
String leaderboardBadgeSemantics(
  LeaderboardBadge badge,
  LeaderboardEntry entry,
) => badge == LeaderboardBadge.streak
    ? AppStrings.streakLabel(entry.currentStreak ?? 0)
    : _keyLabel(badge);

/// [entry]'s [badges] as small icons after a name; the flame shows the
/// streak's day count when [showStreakCount].
class LeaderboardBadgeIcons extends StatelessWidget {
  const LeaderboardBadgeIcons({
    super.key,
    required this.entry,
    required this.badges,
    this.size = 15,
    this.showStreakCount = true,
  });

  final LeaderboardEntry entry;
  final List<LeaderboardBadge> badges;
  final double size;
  final bool showStreakCount;

  @override
  Widget build(BuildContext context) {
    final countStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: _color(LeaderboardBadge.streak),
      fontWeight: FontWeight.w800,
      fontSize: size * 0.75,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, badge) in badges.indexed) ...[
          if (i > 0) const SizedBox(width: 3),
          Semantics(
            label: leaderboardBadgeSemantics(badge, entry),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(_icon(badge), size: size, color: _color(badge)),
                if (badge == LeaderboardBadge.streak && showStreakCount)
                  Text('${entry.currentStreak}', style: countStyle),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One line saying what the badge icons mean: only the kinds in [badges],
/// always in the same order. Nothing when the board has none.
class LeaderboardBadgeKey extends StatelessWidget {
  const LeaderboardBadgeKey({super.key, required this.badges});

  final Set<LeaderboardBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final badge in LeaderboardBadge.values)
            if (badges.contains(badge))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(_icon(badge), size: 14, color: _color(badge)),
                  const SizedBox(width: 4),
                  Text(_keyLabel(badge), style: style),
                ],
              ),
        ],
      ),
    );
  }
}
