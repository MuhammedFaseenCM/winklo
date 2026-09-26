import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

class FloatingNavDock extends StatelessWidget {
  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = <_DockDestination>[
    _DockDestination(
      label: AppStrings.navHome,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _DockDestination(
      label: AppStrings.navLeaderboard,
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
    ),
    _DockDestination(
      label: AppStrings.navProfile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  static const _pillWidth = 44.0;
  static const _pillHeight = 32.0;
  static const _animDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    // Scaffold.bottomNavigationBar often zeroes MediaQuery.padding.bottom.
    // viewPadding keeps the true device inset (home indicator / gesture bar).
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Container(
        key: const Key('floating_nav_dock'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: ZipColors.ember.withValues(alpha: 0.08),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF0243248), Color(0xF0182234)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / _destinations.length;
                  final pillLeft =
                      selectedIndex * tabWidth + (tabWidth - _pillWidth) / 2;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        key: const Key('floating_nav_dock_pill'),
                        duration: _animDuration,
                        curve: Curves.easeOutCubic,
                        left: pillLeft,
                        top: 0,
                        width: _pillWidth,
                        height: _pillHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                ZipColors.ember.withValues(alpha: 0.28),
                                ZipColors.ember.withValues(alpha: 0.16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ZipColors.ember.withValues(alpha: 0.55),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ZipColors.ember.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < _destinations.length; i++)
                            Expanded(
                              child: _DockItem(
                                destination: _destinations[i],
                                selected: selectedIndex == i,
                                onTap: () => onDestinationSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockDestination {
  const _DockDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _DockDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _animDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZipColors.ember : ZipColors.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: FloatingNavDock._pillWidth,
                  height: FloatingNavDock._pillHeight,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: _animDuration,
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.85,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        key: ValueKey<bool>(selected),
                        color: color,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: _animDuration,
                  curve: Curves.easeOut,
                  style:
                      (Theme.of(context).textTheme.labelSmall ??
                              const TextStyle())
                          .copyWith(
                            color: color,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
