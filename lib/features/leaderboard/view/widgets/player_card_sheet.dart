import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/strings/clean_run_chips.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/entities/leaderboard_period.dart';

/// Opens the card for a tapped leaderboard row. Everything on it comes from
/// the entry, so it needs no extra read.
Future<void> showPlayerCardSheet(
  BuildContext context, {
  required LeaderboardEntry entry,
  required String gameId,
  required LeaderboardPeriod period,
  bool isYou = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ZipColors.ink,
    builder: (_) => SingleChildScrollView(
      child: PlayerCard(
        entry: entry,
        gameId: gameId,
        period: period,
        isYou: isYou,
      ),
    ),
  );
}

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.entry,
    required this.gameId,
    required this.period,
    this.isYou = false,
  });

  final LeaderboardEntry entry;
  final String gameId;
  final LeaderboardPeriod period;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekly = period == LeaderboardPeriod.weekly;
    final chips = [
      if (isYou) AppStrings.youLabel,
      if (period == LeaderboardPeriod.daily)
        ...cleanRunChips(
          gameId: gameId,
          usedHints: entry.usedHints,
          hadMistakes: entry.hadMistakes,
        ),
    ];
    final streak = entry.currentStreak;
    final time = AppStrings.formatPlayTime(entry.timeSeconds);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
              displayName: entry.displayName,
              photoUrl: entry.photoUrl,
              avatarId: entry.avatarId,
              radius: 36,
            ),
            const SizedBox(height: 12),
            Text(
              entry.displayName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.playerCardRank(entry.rank),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ZipColors.inkSoft,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (weekly)
                  Expanded(
                    child: _Stat(
                      label: AppStrings.playerCardDays,
                      value: '${entry.daysCleared ?? 0}',
                    ),
                  ),
                Expanded(
                  child: _Stat(
                    label: weekly
                        ? AppStrings.playerCardWeekTotal
                        : AppStrings.playerCardTime,
                    value: time,
                  ),
                ),
              ],
            ),
            if (chips.isNotEmpty || (streak != null && streak >= 1)) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in chips) _Chip(label: chip),
                  if (streak != null && streak >= 1)
                    _Chip(
                      label: AppStrings.streakLabel(streak),
                      icon: Icons.local_fire_department_rounded,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ZipColors.wall.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZipColors.outlineQuiet.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: ZipColors.ember,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: ZipColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ZipColors.emberSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ZipColors.ember.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ZipColors.ember),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ZipColors.ember,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
