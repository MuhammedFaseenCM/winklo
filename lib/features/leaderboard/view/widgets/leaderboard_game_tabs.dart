import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/pill_tabs.dart';
import '../../../../domain/game_ids.dart';

/// Zip · Path Words · Sudoku, with a sliding ember pill under the pick.
class LeaderboardGameTabs extends StatelessWidget {
  const LeaderboardGameTabs({
    super.key,
    required this.gameId,
    required this.onChanged,
  });

  final String gameId;
  final ValueChanged<String> onChanged;

  static const _segments = [
    (value: GameIds.zip, icon: AppIcons.lightning),
    (value: GameIds.pathWords, icon: AppIcons.path),
    (value: GameIds.sudoku, icon: AppIcons.grid),
  ];

  static String _label(String gameId) => switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTab,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };

  @override
  Widget build(BuildContext context) {
    return PillTabs<String>(
      tabs: [
        for (final segment in _segments)
          PillTab(
            value: segment.value,
            icon: segment.icon,
            label: _label(segment.value),
          ),
      ],
      selected: gameId,
      onChanged: onChanged,
    );
  }
}
