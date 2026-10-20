import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../domain/achievements/achievement.dart';
import '../../../domain/achievements/next_achievement.dart';
import '../../stats/cubit/stats_state.dart';
import 'achievement_copy.dart';
import 'achievement_medal.dart';

/// Profile's badges at a glance: the count, a progress bar, the earned
/// medals in one row and the badge to chase next. Tapping it calls [onOpen]
/// (the Badges screen).
class BadgesSummaryCard extends StatelessWidget {
  const BadgesSummaryCard({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final StatsState state;
  final VoidCallback onOpen;

  static const double _medal = 40;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = state.status == StatsStatus.ready;
    final total = Achievements.all.length;
    final earned = [
      for (final a in Achievements.all)
        if (state.unlocked.contains(a.id)) a,
    ];
    final next = ready
        ? nextAchievement(
            state.unlocked,
            currentStreakByGame: {
              for (final entry in state.stats.entries)
                entry.key: entry.value.currentStreak,
            },
          )
        : null;
    final nextDetail = next == null ? null : _nextDetail(next);
    final progress = AppStrings.achievementsProgress(earned.length, total);
    final semanticsLabel = [
      AppStrings.achievementsTitle,
      if (ready) progress,
      if (ready && next != null)
        '${AppStrings.achievementNext(achievementTitle(next))}, $nextDetail',
      if (ready && next == null) AppStrings.achievementsAllEarned,
    ].join('. ');

    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onOpen,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ZipColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZipColors.glassBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.achievementsTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: ZipColors.onInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (ready)
                        Text(
                          progress,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: ZipColors.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const AppIcon(
                        AppIcons.chevronRight,
                        color: ZipColors.inkSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ready ? earned.length / total : 0,
                        minHeight: 6,
                        backgroundColor: ZipColors.paper,
                        color: ZipColors.ember,
                      ),
                    ),
                  ),
                  if (ready && earned.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _EarnedRow(earned: earned),
                  ],
                  if (ready) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _NextRow(next: next, detail: nextDetail),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "4 of 7 days" for a streak under way, else how to earn [next].
  String _nextDetail(Achievement next) {
    if (next.kind == AchievementKind.streak) {
      final current = state.stats[next.gameId]?.currentStreak ?? 0;
      if (current > 0) {
        return AppStrings.achievementStreakProgress(
          math.min(current, next.target),
          next.target,
        );
      }
    }
    return achievementCondition(next);
  }
}

/// The earned medals, as many as fit; a "+N" circle stands for the rest.
class _EarnedRow extends StatelessWidget {
  const _EarnedRow({required this.earned});

  final List<Achievement> earned;

  @override
  Widget build(BuildContext context) {
    const size = BadgesSummaryCard._medal;
    const gap = BadgesSummaryCard._gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = math.max(1, (constraints.maxWidth + gap) ~/ (size + gap));
        final overflow = earned.length > fit;
        final shown = overflow ? fit - 1 : earned.length;
        return Row(
          children: [
            for (var i = 0; i < shown; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              AchievementMedal(
                achievement: earned[i],
                unlocked: true,
                size: size,
              ),
            ],
            if (overflow) ...[
              if (shown > 0) const SizedBox(width: gap),
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZipColors.emberSoft,
                  border: Border.all(
                    color: ZipColors.ember.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '+${earned.length - shown}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ZipColors.ember,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "Next: 7-day Zip streak · 4 of 7 days", or every badge earned.
class _NextRow extends StatelessWidget {
  const _NextRow({required this.next, required this.detail});

  final Achievement? next;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final next = this.next;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ZipColors.mist.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZipColors.outlineQuiet.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          if (next != null)
            AchievementMedal(achievement: next, unlocked: false, size: 32)
          else
            const AppIcon(AppIcons.flawless, size: 28, color: ZipColors.ember),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  next == null
                      ? AppStrings.achievementsAllEarned
                      : AppStrings.achievementNext(achievementTitle(next)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: ZipColors.onInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail case final detail?) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
