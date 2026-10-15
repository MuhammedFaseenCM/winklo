import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/play_mode_route.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/archive_calendar.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_mode.dart';
import '../../../domain/repositories/play_mode_record_repository.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../auth/view/ensure_signed_in_for_play.dart';
import '../cubit/archive_cubit.dart';
import 'more_play_widgets.dart';

/// Past dailies, a month at a time, for one game. A ✓ marks a day cleared
/// in the daily or the archive; tapping a day plays it in archive mode.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, this.initialGameId = GameIds.zip, this.now});

  final String initialGameId;

  /// The clock, for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ArchiveCubit(
        getBestPoints: context.read<GetBestPoints>(),
        getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
        records: context.read<PlayModeRecordRepository>(),
        initialGameId: initialGameId,
        now: now,
      )..load(),
      child: const _ArchiveView(),
    );
  }
}

class _ArchiveView extends StatelessWidget {
  const _ArchiveView();

  /// The calendar reloads itself when the run stores a best
  /// ([ArchiveCubit] listens to the records), since Results replaces the
  /// game page and this push never returns.
  Future<void> _play(BuildContext context, String gameId, DateTime day) async {
    final ok = await ensureSignedInForPlay(context);
    if (!ok || !context.mounted) return;
    await context.push(PlayMode.archive(day).location(gameRoute(gameId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: BlocBuilder<ArchiveCubit, ArchiveState>(
            builder: (context, state) {
              final month = state.month;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MorePlayHeader(title: AppStrings.archiveTitle),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _GamePicker(
                          selected: state.gameId,
                          onSelected: context.read<ArchiveCubit>().selectGame,
                        ),
                        const SizedBox(height: 12),
                        if (month == null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              AppStrings.archiveEmpty,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: ZipColors.inkSoft),
                            ),
                          )
                        else
                          _MonthCard(
                            state: state,
                            month: month,
                            onDay: (day) => _play(context, state.gameId, day),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.archiveOpenHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ZipColors.inkSoft),
                        ),
                        const SizedBox(height: 6),
                        const _Legend(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GamePicker extends StatelessWidget {
  const _GamePicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        foregroundColor: ZipColors.inkSoft,
        selectedForegroundColor: ZipColors.ink,
        selectedBackgroundColor: ZipColors.ember,
        side: const BorderSide(color: ZipColors.outline),
        visualDensity: VisualDensity.compact,
      ),
      segments: [
        for (final gameId in ArchiveCubit.games)
          ButtonSegment(
            value: gameId,
            label: Text(
              MorePlayGameStyle.of(gameId).title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onSelected(values.single),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.state,
    required this.month,
    required this.onDay,
  });

  final ArchiveState state;
  final ArchiveMonth month;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final cubit = context.read<ArchiveCubit>();
    final index = state.months.indexOf(month);
    final style = MorePlayGameStyle.of(state.gameId);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZipColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: AppStrings.archivePrevious,
                color: ZipColors.onInk,
                disabledColor: ZipColors.outline,
                onPressed: index > 0 ? () => cubit.showMonth(index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      localizations.formatMonthYear(
                        DateTime(month.year, month.month),
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      AppStrings.archiveMonthCleared(month.clearedDays.length),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ZipColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppStrings.archiveNext,
                color: ZipColors.onInk,
                disabledColor: ZipColors.outline,
                onPressed: index < state.months.length - 1
                    ? () => cubit.showMonth(index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _MonthGrid(month: month, accent: style.accent, onDay: onDay),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.accent,
    required this.onDay,
  });

  final ArchiveMonth month;
  final Color accent;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final firstDay = localizations.firstDayOfWeekIndex;
    final blanks = month.leadingBlanks(firstDayOfWeekIndex: firstDay);
    final rows = ((blanks + month.daysInMonth) / 7).ceil();
    final weekdays = localizations.narrowWeekdays;

    Widget cell(int index) {
      final day = index - blanks + 1;
      if (day < 1 || day > month.daysInMonth) return const SizedBox.shrink();
      final date = DateTime(month.year, month.month, day);
      final playable = month.isPlayable(day);
      final cleared = month.clearedDays.contains(day);
      final label = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: theme.textTheme.labelLarge?.copyWith(
              color: !playable
                  ? ZipColors.outline
                  : cleared
                  ? ZipColors.ink
                  : ZipColors.onInk,
              fontWeight: playable ? FontWeight.w800 : FontWeight.w500,
              height: 1.1,
            ),
          ),
          if (cleared)
            const Icon(Icons.check_rounded, size: 13, color: ZipColors.ink),
        ],
      );
      return Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          button: playable,
          label: localizations.formatMediumDate(date),
          value: playable
              ? (cleared
                    ? AppStrings.archiveDayCleared
                    : AppStrings.archiveDayOpen)
              : null,
          excludeSemantics: true,
          child: Material(
            color: cleared
                ? accent
                : playable
                ? ZipColors.paper
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: playable && !cleared
                  ? BorderSide(color: accent.withValues(alpha: 0.45))
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('archive-day-$day'),
              onTap: playable ? () => onDay(date) : null,
              child: Center(child: label),
            ),
          ),
        ),
      );
    }

    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w700,
    );
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Text(
                  weekdays[(firstDay + i) % 7],
                  textAlign: TextAlign.center,
                  style: headerStyle,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: cell(row * 7 + col),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final accent = MorePlayGameStyle.of(
      context.select((ArchiveCubit c) => c.state.gameId),
    ).accent;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 13,
            color: ZipColors.ink,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            AppStrings.archiveLegend,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
          ),
        ),
      ],
    );
  }
}
