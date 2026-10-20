import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/app_update_repository.dart';
import '../../../../domain/repositories/in_app_update_repository.dart';
import '../../../../domain/repositories/update_banner_snooze_repository.dart';
import '../../../app_update/cubit/soft_update_cubit.dart';
import '../../../app_update/cubit/soft_update_state.dart';
import 'home_update_banner.dart';

/// Home's soft update banner, [gap] below the header: it can be closed for a
/// day, and updates through Play in place before falling back to the store.
class HomeSoftUpdateSection extends StatelessWidget {
  const HomeSoftUpdateSection({
    super.key,
    required this.currentLabel,
    required this.requiredLabel,
    required this.storeUrl,
    this.gap = 12,
  });

  final String currentLabel;
  final String requiredLabel;
  final String storeUrl;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SoftUpdateCubit(
        inAppUpdates: context.read<InAppUpdateRepository>(),
        appUpdateRepository: context.read<AppUpdateRepository>(),
        snooze: context.read<UpdateBannerSnoozeRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      )..checkDownloaded(),
      child: BlocBuilder<SoftUpdateCubit, SoftUpdateState>(
        builder: (context, state) {
          final cubit = context.read<SoftUpdateCubit>();
          // Read on every build: Home rebuilds when it reloads, so the
          // banner comes back once the day is over.
          if (cubit.isHidden) return const SizedBox.shrink();
          final (label, icon) = switch (state.phase) {
            SoftUpdatePhase.idle => (AppStrings.updateNow, AppIcons.download),
            SoftUpdatePhase.downloading => (
              AppStrings.updateDownloading,
              AppIcons.downloading,
            ),
            SoftUpdatePhase.readyToInstall => (
              AppStrings.updateRestart,
              AppIcons.replay,
            ),
          };
          return Padding(
            padding: EdgeInsets.only(top: gap),
            child: HomeUpdateBanner(
              currentLabel: currentLabel,
              requiredLabel: requiredLabel,
              updateLabel: label,
              updateIcon: icon,
              onUpdate: state.phase == SoftUpdatePhase.downloading
                  ? null
                  : () => unawaited(cubit.update(storeUrl)),
              onSnooze: () => unawaited(cubit.snooze()),
            ),
          );
        },
      ),
    );
  }
}
