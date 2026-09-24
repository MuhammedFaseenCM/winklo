import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../../leaderboard/cubit/leaderboard_cubit.dart';
import '../../leaderboard/cubit/leaderboard_state.dart';
import '../../leaderboard/logic/mini_leaderboard_slice.dart';
import '../../leaderboard/view/widgets/leaderboard_row.dart';

class MiniLeaderboardPanel extends StatelessWidget {
  const MiniLeaderboardPanel({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
        initialGameId: gameId,
      ),
      child: _MiniLeaderboardPanelBody(gameId: gameId),
    );
  }
}

class _MiniLeaderboardPanelBody extends StatelessWidget {
  const _MiniLeaderboardPanelBody({required this.gameId});

  final String gameId;

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.leaderboardTitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: ZipColors.onInk),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
            builder: (context, state) {
              final signedIn = context.watch<AuthCubit>().isSignedIn;
              if (!signedIn) {
                return _MessageBody(
                  message: AppStrings.leaderboardSignInHint,
                  actionLabel: AppStrings.signInWithGoogle,
                  onAction: () => showSignInSheet(context),
                );
              }
              switch (state.status) {
                case LeaderboardStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case LeaderboardStatus.failure:
                  return _MessageBody(
                    message: state.error ?? AppStrings.leaderboardFailed,
                    actionLabel: AppStrings.retry,
                    onAction: () => context.read<LeaderboardCubit>().retry(),
                  );
                case LeaderboardStatus.ready:
                  if (state.entries.isEmpty) {
                    return const _MessageBody(
                      message: AppStrings.leaderboardEmpty,
                    );
                  }
                  final items = sliceLeaderboardForMini(
                    entries: state.entries,
                    currentUid: state.currentUid,
                  );
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return switch (item) {
                        MiniLeaderboardGap() => Center(
                          child: Text(
                            AppStrings.leaderboardGapEllipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: ZipColors.inkSoft),
                          ),
                        ),
                        MiniLeaderboardEntryItem(:final entry) =>
                          LeaderboardRow(
                            entry: entry,
                            timeLabel: _formatTime(entry.timeSeconds),
                            isYou: entry.uid == state.currentUid,
                          ),
                      };
                    },
                  );
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        ZipPrimaryButton(
          label: AppStrings.seeFullLeaderboard,
          icon: Icons.leaderboard_rounded,
          onPressed: () => context.go('/leaderboard?game=$gameId'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => context.go('/'),
          child: Text(AppStrings.backHome),
        ),
      ],
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: ZipColors.inkSoft),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
