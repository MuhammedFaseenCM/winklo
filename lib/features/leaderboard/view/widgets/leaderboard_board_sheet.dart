import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/entities/leaderboard_period.dart';
import '../../logic/board_calendar.dart';
import 'leaderboard_sheet_parts.dart';

/// What the board sheet picked: a period and, for the daily board, its day.
class LeaderboardBoardChoice {
  const LeaderboardBoardChoice(this.period, {this.dayId});

  final LeaderboardPeriod period;

  /// `yyyy-MM-dd`; only for [LeaderboardPeriod.daily].
  final String? dayId;
}

/// "Which board?": This week, All-time (when [showAllTime]), or one of the
/// [recentDayIds] (today first) on a Monday-first calendar. Null when
/// dismissed.
Future<LeaderboardBoardChoice?> showLeaderboardBoardSheet(
  BuildContext context, {
  required LeaderboardPeriod period,
  required String? dayId,
  required List<String> recentDayIds,
  required bool showAllTime,
}) {
  return showModalBottomSheet<LeaderboardBoardChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: ZipColors.ink,
    builder: (sheetContext) {
      void pick(LeaderboardBoardChoice choice) =>
          Navigator.of(sheetContext).pop(choice);
      final today = recentDayIds.isEmpty ? null : recentDayIds.first;
      return LeaderboardSheetFrame(
        title: AppStrings.leaderboardBoardSheetTitle,
        children: [
          LeaderboardSheetOption(
            key: const Key('leaderboard_board_weekly'),
            leading: const AppIcon(AppIcons.week, color: ZipColors.sky),
            label: AppStrings.leaderboardThisWeek,
            subtitle: AppStrings.leaderboardThisWeekHint,
            selected: period == LeaderboardPeriod.weekly,
            onTap: () =>
                pick(const LeaderboardBoardChoice(LeaderboardPeriod.weekly)),
          ),
          if (showAllTime)
            LeaderboardSheetOption(
              key: const Key('leaderboard_board_all_time'),
              leading: const AppIcon(AppIcons.medal, color: Color(0xFFFFD700)),
              label: AppStrings.leaderboardAllTime,
              subtitle: AppStrings.leaderboardAllTimeHint,
              selected: period == LeaderboardPeriod.allTime,
              onTap: () =>
                  pick(const LeaderboardBoardChoice(LeaderboardPeriod.allTime)),
            ),
          const SizedBox(height: 10),
          Text(
            AppStrings.leaderboardSingleDayLabel,
            style: Theme.of(
              sheetContext,
            ).textTheme.labelMedium?.copyWith(color: ZipColors.inkSoft),
          ),
          const SizedBox(height: 8),
          _BoardCalendar(
            weeks: boardCalendarWeeks(recentDayIds),
            todayId: today,
            selectedDayId: period == LeaderboardPeriod.daily
                ? (dayId ?? today)
                : null,
            onPicked: (id) => pick(
              LeaderboardBoardChoice(LeaderboardPeriod.daily, dayId: id),
            ),
          ),
        ],
      );
    },
  );
}

class _BoardCalendar extends StatelessWidget {
  const _BoardCalendar({
    required this.weeks,
    required this.todayId,
    required this.selectedDayId,
    required this.onPicked,
  });

  final List<List<BoardCalendarDay>> weeks;
  final String? todayId;
  final String? selectedDayId;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    // narrowWeekdays starts on Sunday; the weekly board's weeks start Monday.
    final weekdays = [
      for (var i = 0; i < 7; i++) localizations.narrowWeekdays[(i + 1) % 7],
    ];
    return Column(
      children: [
        Row(
          children: [
            for (final weekday in weekdays)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final week in weeks)
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _DayCell(
                      day: day,
                      isToday: day.dayId == todayId,
                      selected: day.dayId == selectedDayId,
                      onTap: () => onPicked(day.dayId),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  final BoardCalendarDay day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (!day.inWindow) {
      return ExcludeSemantics(
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              '${day.dayOfMonth}',
              style: textTheme.labelLarge?.copyWith(
                color: ZipColors.outlineQuiet,
              ),
            ),
          ),
        ),
      );
    }
    final parts = day.dayId.split('-').map(int.parse).toList();
    final date = DateTime(parts[0], parts[1], parts[2]);
    final color = selected
        ? Colors.white
        : isToday
        ? ZipColors.ember
        : ZipColors.onInk;
    return Semantics(
      key: Key('leaderboard_day_${day.dayId}'),
      button: true,
      selected: selected,
      label: MaterialLocalizations.of(context).formatMediumDate(date),
      // excludeSemantics drops the InkWell's own tap action.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? ZipColors.ember
            : ZipColors.mist.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
            color: selected
                ? ZipColors.ember
                : isToday
                ? ZipColors.ember.withValues(alpha: 0.7)
                : ZipColors.outlineQuiet.withValues(alpha: 0.7),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                '${day.dayOfMonth}',
                style: textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
