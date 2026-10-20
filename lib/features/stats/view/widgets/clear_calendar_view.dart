import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/stats/clear_calendar.dart';

/// One month of cleared days at a time, newest first, with arrows to page
/// back through earlier months.
class ClearCalendarView extends StatefulWidget {
  const ClearCalendarView({
    super.key,
    required this.months,
    required this.today,
  });

  /// Oldest first, as `clearCalendar` returns them.
  final List<ClearCalendarMonth> months;
  final DateTime today;

  @override
  State<ClearCalendarView> createState() => _ClearCalendarViewState();
}

class _ClearCalendarViewState extends State<ClearCalendarView> {
  late int _index = widget.months.length - 1;

  @override
  void didUpdateWidget(ClearCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.months.length != widget.months.length) {
      _index = widget.months.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.months.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, widget.months.length - 1);
    final month = widget.months[index];
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final title = localizations.formatMonthYear(
      DateTime(month.year, month.month),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: AppStrings.statsCalendarPrevious,
              visualDensity: VisualDensity.compact,
              color: ZipColors.onInk,
              disabledColor: ZipColors.outline,
              onPressed: index > 0
                  ? () => setState(() => _index = index - 1)
                  : null,
              icon: const AppIcon(AppIcons.chevronLeft),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: ZipColors.onInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    AppStrings.statsCalendarCleared(month.clearedDays.length),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ZipColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: AppStrings.statsCalendarNext,
              visualDensity: VisualDensity.compact,
              color: ZipColors.onInk,
              disabledColor: ZipColors.outline,
              onPressed: index < widget.months.length - 1
                  ? () => setState(() => _index = index + 1)
                  : null,
              icon: const AppIcon(AppIcons.chevronRight),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MonthGrid(month: month, today: widget.today),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.today});

  final ClearCalendarMonth month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final firstDay = localizations.firstDayOfWeekIndex;
    final blanks = month.leadingBlanks(firstDayOfWeekIndex: firstDay);
    final cells = blanks + month.daysInMonth;
    final rows = (cells / 7).ceil();
    final weekdays = localizations.narrowWeekdays;
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: ZipColors.inkSoft,
      fontWeight: FontWeight.w700,
    );
    final isTodayMonth = today.year == month.year && today.month == month.month;

    Widget cell(int index) {
      final day = index - blanks + 1;
      if (day < 1 || day > month.daysInMonth) return const SizedBox.shrink();
      final cleared = month.clearedDays.contains(day);
      final isToday = isTodayMonth && today.day == day;
      return Padding(
        padding: const EdgeInsets.all(2),
        child: Semantics(
          label: localizations.formatMediumDate(
            DateTime(month.year, month.month, day),
          ),
          value: cleared ? AppStrings.cleared : null,
          excludeSemantics: true,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cleared ? ZipColors.ember : null,
              border: isToday && !cleared
                  ? Border.all(color: ZipColors.inkSoft, width: 1.5)
                  : null,
            ),
            child: Text(
              '$day',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cleared ? ZipColors.ink : ZipColors.inkSoft,
                fontWeight: cleared ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

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
                    aspectRatio: 1.25,
                    child: cell(row * 7 + col),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
