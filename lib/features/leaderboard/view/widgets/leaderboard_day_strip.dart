import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

/// "Today", "Yesterday", or a short date for the board day [dayId]
/// (`yyyy-MM-dd`) at [index] in the strip (today is 0).
String leaderboardDayLabel(String dayId, int index) {
  if (index == 0) return AppStrings.leaderboardToday;
  if (index == 1) return AppStrings.leaderboardYesterday;
  final parts = dayId.split('-');
  return AppStrings.leaderboardShortDate(
    int.parse(parts[2]),
    int.parse(parts[1]),
  );
}

/// The daily board's days: today first, then the 13 before it. Past days are
/// read-only snapshots of their board.
class LeaderboardDayStrip extends StatelessWidget {
  const LeaderboardDayStrip({
    super.key,
    required this.dayIds,
    required this.selectedDayId,
    required this.onSelected,
  });

  /// Today first.
  final List<String> dayIds;

  /// Null is today.
  final String? selectedDayId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = selectedDayId ?? (dayIds.isEmpty ? null : dayIds.first);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        key: const Key('leaderboard_day_strip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dayIds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final dayId = dayIds[index];
          final isSelected = dayId == selected;
          return _DayChip(
            label: leaderboardDayLabel(dayId, index),
            selected: isSelected,
            onTap: () => onSelected(dayId),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? ZipColors.emberSoft
            : ZipColors.wall.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? ZipColors.ember.withValues(alpha: 0.6)
                : ZipColors.outlineQuiet.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? ZipColors.ember : ZipColors.inkSoft,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
