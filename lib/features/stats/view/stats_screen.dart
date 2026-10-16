import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/stats/game_stats.dart';
import '../../../domain/usecases/load_game_history.dart';
import '../cubit/stats_cubit.dart';
import '../cubit/stats_state.dart';
import 'widgets/best_trend_chart.dart';
import 'widgets/clear_calendar_view.dart';
import 'widgets/stat_tiles.dart';
import 'widgets/stats_card.dart';
import 'widgets/time_histogram_chart.dart';

/// `/profile/stats`: a tab per daily game with its numbers, a clear-time
/// histogram, a calendar of cleared days and the personal-best trend.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, this.initialGameId = GameIds.zip});

  final String initialGameId;

  static const games = [GameIds.zip, GameIds.pathWords, GameIds.sudoku];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StatsCubit(
        loadHistory: context.read<LoadGameHistory>(),
        // Opening the screen picks up clears made on other devices.
        refreshRemote: true,
      ),
      child: DefaultTabController(
        length: games.length,
        initialIndex: games.indexOf(initialGameId).clamp(0, games.length - 1),
        child: Scaffold(
          backgroundColor: ZipColors.ink,
          appBar: AppBar(
            title: Text(
              AppStrings.statsTitle,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: ZipColors.onInk,
            bottom: TabBar(
              indicatorColor: ZipColors.ember,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: ZipColors.onInk,
              unselectedLabelColor: ZipColors.inkSoft,
              dividerColor: ZipColors.outlineQuiet,
              tabs: [
                Tab(text: AppStrings.zipTitle),
                Tab(text: AppStrings.pathWordsTitle),
                Tab(text: AppStrings.sudokuTitle),
              ],
            ),
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
                    return TabBarView(
                      children: [
                        for (final gameId in games)
                          _GameStatsPage(
                            stats: state.stats[gameId]!,
                            today: state.history!.today,
                            localOnly: state.remoteFailed,
                          ),
                      ],
                    );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GameStatsPage extends StatelessWidget {
  const _GameStatsPage({
    required this.stats,
    required this.today,
    required this.localOnly,
  });

  final GameStats stats;
  final DateTime today;
  final bool localOnly;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final gap = SizedBox(height: layout.sectionGap);
    return RefreshIndicator(
      color: ZipColors.ember,
      backgroundColor: ZipColors.wall,
      onRefresh: () => context.read<StatsCubit>().load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Clear of the shell's floating nav dock (extendBody).
        padding: layout.scrollPadding(context),
        children: [
          if (localOnly) ...[_LocalOnlyNote(), gap],
          StatTiles(stats: stats),
          gap,
          StatsCard(
            title: AppStrings.statsTimesTitle,
            emptyMessage: stats.histogram.isEmpty
                ? AppStrings.statsTimesEmpty
                : null,
            child: TimeHistogramChart(buckets: stats.histogram),
          ),
          gap,
          StatsCard(
            title: AppStrings.statsCalendarTitle,
            emptyMessage: stats.calendar.isEmpty
                ? AppStrings.statsCalendarEmpty
                : null,
            child: ClearCalendarView(months: stats.calendar, today: today),
          ),
          gap,
          StatsCard(
            title: AppStrings.statsTrendTitle,
            subtitle: AppStrings.statsTrendSubtitle,
            emptyMessage: stats.trend.isEmpty
                ? AppStrings.statsTrendEmpty
                : null,
            child: BestTrendChart(points: stats.trend),
          ),
        ],
      ),
    );
  }
}

class _LocalOnlyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: ZipColors.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.statsLocalOnly,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
          ),
        ),
      ],
    );
  }
}
