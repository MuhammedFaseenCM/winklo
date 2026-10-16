import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
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
    (value: GameIds.zip, icon: Icons.bolt_rounded),
    (value: GameIds.pathWords, icon: Icons.route_rounded),
    (value: GameIds.sudoku, icon: Icons.grid_on_rounded),
  ];

  static String _label(String gameId) => switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTab,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _segments.indexWhere((s) => s.value == gameId);
    return Container(
      decoration: BoxDecoration(
        color: ZipColors.wall.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: ZipColors.outlineQuiet.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / _segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: (selectedIndex < 0 ? 0 : selectedIndex) * pillWidth,
                top: 0,
                bottom: 0,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: ZipColors.ember,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: ZipColors.emberGlow,
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final segment in _segments)
                    Expanded(
                      child: _GameTab(
                        icon: segment.icon,
                        label: _label(segment.value),
                        selected: segment.value == gameId,
                        onTap: () => onChanged(segment.value),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GameTab extends StatelessWidget {
  const _GameTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : ZipColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: withMalayalamFallback(
                        GoogleFonts.lexend(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.2,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
