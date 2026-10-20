import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';

/// One choice of [PillTabs].
class PillTab<T> {
  const PillTab({
    required this.value,
    required this.icon,
    required this.label,
    this.key,
  });

  final T value;
  final IconData icon;
  final String label;

  /// Finds the tab in tests.
  final Key? key;
}

/// Equal tabs in a dark track, with a sliding ember pill under the pick:
/// the Leaderboard tab's games, and Results' Board | Words.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<PillTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = tabs.indexWhere((t) => t.value == selected);
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
          final pillWidth = constraints.maxWidth / tabs.length;
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
                  for (final tab in tabs)
                    Expanded(
                      child: _PillTabButton(
                        key: tab.key,
                        icon: tab.icon,
                        label: tab.label,
                        selected: tab.value == selected,
                        onTap: () => onChanged(tab.value),
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

class _PillTabButton extends StatelessWidget {
  const _PillTabButton({
    super.key,
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(icon, size: 17, color: color),
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
