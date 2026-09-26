import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/floating_nav_dock.dart';
import 'widgets/tab_switch_animator.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: TabSwitchAnimator(
        index: navigationShell.currentIndex,
        child: navigationShell,
      ),
      bottomNavigationBar: FloatingNavDock(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
