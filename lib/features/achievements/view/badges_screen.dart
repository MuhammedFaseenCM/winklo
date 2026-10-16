import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/achievements/achievement.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/usecases/load_game_history.dart';
import '../../stats/cubit/stats_cubit.dart';
import '../../stats/cubit/stats_state.dart';
import '../../stats/view/widgets/stats_card.dart';
import 'achievement_copy.dart';
import 'achievement_medal.dart';

/// `/profile/badges`: every badge. A ladder per game (first clear, then 7,
/// 30 and 100 days in a row) and the special ones, earned or how to earn.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  static const games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StatsCubit(
        loadHistory: context.read<LoadGameHistory>(),
        // Opening the screen picks up clears made on other devices.
        refreshRemote: true,
      ),
      child: Scaffold(
        backgroundColor: ZipColors.ink,
        appBar: AppBar(
          title: Text(
            AppStrings.achievementsTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: ZipColors.onInk,
        ),
        body: ZipAtmosphere(
          child: BlocBuilder<StatsCubit, StatsState>(
            builder: (context, state) {
              switch (state.status) {
                case StatsStatus.loading:
                  return const Center(
                    child: CircularProgressIndicator(color: ZipColors.ember),
                  );
                case StatsStatus.failure:
                  return CenteredMessageBody(
                    message: AppStrings.statsFailed,
                    actionLabel: AppStrings.retry,
                    onAction: () =>
                        context.read<StatsCubit>().load(refresh: true),
                  );
                case StatsStatus.ready:
                  return _BadgesBody(state: state);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _BadgesBody extends StatelessWidget {
  const _BadgesBody({required this.state});

  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final gap = SizedBox(height: layout.sectionGap);
    final unlocked = state.unlocked;
    final total = Achievements.all.length;
    final earned = Achievements.all.where((a) => unlocked.contains(a.id));
    return RefreshIndicator(
      color: ZipColors.ember,
      backgroundColor: ZipColors.wall,
      onRefresh: () => context.read<StatsCubit>().load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Clear of the shell's floating nav dock (extendBody).
        padding: layout.scrollPadding(context),
        children: [
          _Summary(earned: earned.length, total: total),
          gap,
          for (final gameId in BadgesScreen.games) ...[
            _GameLadderCard(
              gameId: gameId,
              unlocked: unlocked,
              currentStreak: state.stats[gameId]?.currentStreak ?? 0,
            ),
            gap,
          ],
          _SpecialCard(unlocked: unlocked),
        ],
      ),
    );
  }
}

/// "4 of 16" over a progress bar.
class _Summary extends StatelessWidget {
  const _Summary({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.achievementsProgress(earned, total),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: ZipColors.onInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : earned / total,
              minHeight: 8,
              backgroundColor: ZipColors.paper,
              color: ZipColors.ember,
            ),
          ),
        ],
      ),
    );
  }
}

/// A game's ladder: first clear, then 7, 30 and 100 days in a row, joined
/// by a line that lights between earned steps.
class _GameLadderCard extends StatelessWidget {
  const _GameLadderCard({
    required this.gameId,
    required this.unlocked,
    required this.currentStreak,
  });

  final String gameId;
  final Set<String> unlocked;
  final int currentStreak;

  static const double _medal = 44;

  @override
  Widget build(BuildContext context) {
    final steps = [
      Achievements.byId('first_clear_$gameId')!,
      for (final days in Achievements.streakLengths)
        Achievements.byId('streak_${days}_$gameId')!,
    ];
    final labels = [
      AppStrings.achievementLadderFirst,
      for (final days in Achievements.streakLengths)
        AppStrings.achievementLadderDays(days),
    ];
    final earned = [for (final step in steps) unlocked.contains(step.id)];
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return StatsCard(
      title: gameTitle(gameId),
      subtitle: currentStreak > 0
          ? AppStrings.achievementCurrentStreak(currentStreak)
          : null,
      trailing: Text(
        AppStrings.achievementsProgress(
          earned.where((e) => e).length,
          steps.length,
        ),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ZipColors.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _medal,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final column = constraints.maxWidth / steps.length;
                double center(int i) => column * (i + 0.5);
                return Stack(
                  children: [
                    for (var i = 0; i + 1 < steps.length; i++)
                      Positioned(
                        left: center(i) + _medal / 2,
                        // Never negative, however narrow the card.
                        width: math.max(0, column - _medal),
                        top: _medal / 2 - 1.5,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: earned[i] && earned[i + 1]
                                ? ZipColors.ember
                                : ZipColors.outlineQuiet,
                          ),
                        ),
                      ),
                    for (var i = 0; i < steps.length; i++)
                      Positioned(
                        left: center(i) - _medal / 2,
                        top: 0,
                        child: _BadgeSemantics(
                          achievement: steps[i],
                          unlocked: earned[i],
                          child: AchievementMedal(
                            achievement: steps[i],
                            unlocked: earned[i],
                            size: _medal,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle?.copyWith(
                        color: earned[i] ? ZipColors.onInk : ZipColors.inkSoft,
                        fontWeight: earned[i]
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The badges that aren't a game's ladder, a row each with how to earn it.
class _SpecialCard extends StatelessWidget {
  const _SpecialCard({required this.unlocked});

  final Set<String> unlocked;

  static const _ids = [
    'perfect_day',
    'zip_under_minute',
    'hint_free_week',
    'flawless_sudoku_10',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badges = [for (final id in _ids) Achievements.byId(id)!];
    return StatsCard(
      title: AppStrings.achievementsSpecial,
      trailing: Text(
        AppStrings.achievementsProgress(
          badges.where((a) => unlocked.contains(a.id)).length,
          badges.length,
        ),
        style: textTheme.labelMedium?.copyWith(
          color: ZipColors.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < badges.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _BadgeSemantics(
              achievement: badges[i],
              unlocked: unlocked.contains(badges[i].id),
              child: _SpecialRow(
                achievement: badges[i],
                unlocked: unlocked.contains(badges[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpecialRow extends StatelessWidget {
  const _SpecialRow({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        AchievementMedal(
          achievement: achievement,
          unlocked: unlocked,
          size: 40,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievementTitle(achievement),
                style: textTheme.titleSmall?.copyWith(
                  color: unlocked ? ZipColors.onInk : ZipColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                achievementCondition(achievement),
                style: textTheme.labelSmall?.copyWith(color: ZipColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (unlocked)
          const Icon(Icons.check_circle_rounded, color: ZipColors.ember)
        else
          const SizedBox(width: 24),
      ],
    );
  }
}

/// A badge for screen readers: its name, then "Earned", or "Locked. How
/// to earn it".
class _BadgeSemantics extends StatelessWidget {
  const _BadgeSemantics({
    required this.achievement,
    required this.unlocked,
    required this.child,
  });

  final Achievement achievement;
  final bool unlocked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: achievementTitle(achievement),
      value: unlocked
          ? AppStrings.achievementEarned
          : '${AppStrings.achievementLocked}. '
                '${achievementCondition(achievement)}',
      excludeSemantics: true,
      child: child,
    );
  }
}
