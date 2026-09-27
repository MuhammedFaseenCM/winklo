import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/app_update_decision.dart';
import '../../../domain/repositories/app_update_repository.dart';
import '../../../domain/usecases/check_app_update.dart';
import '../../app_update/cubit/app_update_cubit.dart';
import '../../app_update/cubit/app_update_state.dart';
import '../../home/view/widgets/home_force_update_overlay.dart';
import 'widgets/floating_nav_dock.dart';
import 'widgets/tab_switch_animator.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AppUpdateCubit(
        checkAppUpdate: context.read<CheckAppUpdate>(),
        appUpdateRepository: context.read<AppUpdateRepository>(),
      )..check(),
      child: _DashboardShellView(navigationShell: navigationShell),
    );
  }
}

class _DashboardShellView extends StatelessWidget {
  const _DashboardShellView({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppUpdateCubit, AppUpdateState>(
      builder: (context, updateState) {
        final forced = updateState.status == AppUpdateStatus.forced;
        return Stack(
          children: [
            Scaffold(
              extendBody: true,
              body: TabSwitchAnimator(
                index: navigationShell.currentIndex,
                child: navigationShell,
              ),
              bottomNavigationBar: forced
                  ? null
                  : FloatingNavDock(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) {
                        if (context.read<AppUpdateCubit>().isForced) return;
                        navigationShell.goBranch(
                          index,
                          initialLocation:
                              index == navigationShell.currentIndex,
                        );
                      },
                    ),
            ),
            if (forced)
              HomeForceUpdateOverlay(
                onUpdate: () => context.read<AppUpdateCubit>().openStore(),
              ),
          ],
        );
      },
    );
  }
}
