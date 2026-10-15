import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/habit_repository.dart';
import '../../../../domain/usecases/get_weekly_recap.dart';
import '../../cubit/home_cubit.dart';
import '../../cubit/home_habit_cubit.dart';
import '../../cubit/home_habit_state.dart';
import '../../cubit/home_state.dart';

/// Home's habit cards (freeze saved, weekly recap), reloaded with Home.
/// Sits under [HomeCubit]; takes no space when there is nothing to show.
class HomeHabitCards extends StatelessWidget {
  const HomeHabitCards({super.key, this.now});

  /// The clock, for tests.
  final DateTime Function()? now;

  static Map<String, int> _streaks(HomeState state) => {
    GameIds.zip: state.currentStreak,
    GameIds.pathWords: state.pathWordsCurrentStreak,
    GameIds.sudoku: state.sudokuCurrentStreak,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = HomeHabitCubit(
          habit: context.read<HabitRepository>(),
          weeklyRecap: context.read<GetWeeklyRecap>(),
          now: now,
        );
        final home = context.read<HomeCubit>().state;
        unawaited(cubit.load(currentStreaks: _streaks(home)));
        return cubit;
      },
      child: BlocListener<HomeCubit, HomeState>(
        listenWhen: (previous, next) => previous.loadedAt != next.loadedAt,
        listener: (context, home) => unawaited(
          context.read<HomeHabitCubit>().load(currentStreaks: _streaks(home)),
        ),
        child: BlocBuilder<HomeHabitCubit, HomeHabitState>(
          builder: (context, state) {
            final cubit = context.read<HomeHabitCubit>();
            return HomeHabitCardsView(
              state: state,
              onDismissNotice: cubit.dismissNotice,
              onDismissRecap: () => unawaited(cubit.dismissRecap()),
            );
          },
        ),
      ),
    );
  }
}

class HomeHabitCardsView extends StatelessWidget {
  const HomeHabitCardsView({
    super.key,
    required this.state,
    required this.onDismissNotice,
    required this.onDismissRecap,
  });

  final HomeHabitState state;
  final ValueChanged<String> onDismissNotice;
  final VoidCallback onDismissRecap;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) return const SizedBox.shrink();
    final layout = AppLayout.of(context);
    final notice = state.shownFreezeNotice;
    final recap = state.recap;
    return Padding(
      padding: EdgeInsets.only(top: layout.space(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null)
            _HabitCard(
              icon: Icons.ac_unit_rounded,
              accent: ZipColors.sky,
              body: AppStrings.freezeSavedStreak(notice.gameId, notice.days),
              onDismiss: () => onDismissNotice(notice.gameId),
            ),
          if (recap != null)
            _HabitCard(
              icon: Icons.insights_rounded,
              accent: ZipColors.ember,
              title: AppStrings.homeRecapTitle,
              body: AppStrings.weeklyRecapLine(
                recap,
                lastWeek: state.recapIsLastWeek,
              ),
              onDismiss: onDismissRecap,
            ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.icon,
    required this.accent,
    required this.body,
    required this.onDismiss,
    this.title,
  });

  final IconData icon;
  final Color accent;
  final String? title;
  final String body;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final textTheme = Theme.of(context).textTheme;
    final heading = title;
    return Padding(
      padding: EdgeInsets.only(bottom: layout.space(6)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ZipColors.wall,
          borderRadius: BorderRadius.circular(layout.space(14)),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            layout.space(12),
            layout.space(8),
            layout.space(2),
            layout.space(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: layout.space(20)),
              SizedBox(width: layout.space(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (heading != null)
                      Text(
                        heading,
                        style: textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      body,
                      style: textTheme.bodySmall?.copyWith(
                        color: ZipColors.onInk,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.dismiss,
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: layout.space(18),
                  color: ZipColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
