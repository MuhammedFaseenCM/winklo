import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/lifecycle/progress_change_signal.dart';
import '../../../../core/lifecycle/progress_sync_lifecycle.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/usecases/load_game_history.dart';
import '../../../achievements/view/badges_summary_card.dart';
import '../../../stats/cubit/stats_cubit.dart';
import '../../../stats/cubit/stats_state.dart';

/// Profile's way into `/profile/stats` and `/profile/badges` (a summary of
/// the badges). Renders nothing
/// when the app provides no [LoadGameHistory] (screen tests of Profile).
class ProfileStatsSection extends StatelessWidget {
  const ProfileStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final loadHistory = context.read<LoadGameHistory?>();
    if (loadHistory == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => StatsCubit(
        loadHistory: loadHistory,
        // New clears, and progress a sync restores (another device, an
        // account switch), update the badges while Profile stays mounted.
        reloadOn: [
          ?context.read<ProgressChangeSignal?>()?.changes,
          ?context.read<ProgressSyncLifecycle?>()?.restored,
        ],
      ),
      child: const _ProfileStatsBody(),
    );
  }
}

class _ProfileStatsBody extends StatelessWidget {
  const _ProfileStatsBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              leading: const Icon(
                Icons.insights_rounded,
                color: ZipColors.ember,
              ),
              title: Text(
                AppStrings.statsProfileRow,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: ZipColors.onInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                AppStrings.statsProfileRowHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: ZipColors.inkSoft,
              ),
              onTap: () => context.push('/profile/stats'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BlocBuilder<StatsCubit, StatsState>(
          builder: (context, state) => BadgesSummaryCard(
            state: state,
            onOpen: () => unawaited(_openBadges(context)),
          ),
        ),
      ],
    );
  }
}

/// Opens Badges, then reloads: Badges refreshes the account's remote days,
/// and the plain reload reads that cache without fetching again.
Future<void> _openBadges(BuildContext context) async {
  final cubit = context.read<StatsCubit>();
  await context.push('/profile/badges');
  if (!cubit.isClosed) unawaited(cubit.load());
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZipColors.glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
