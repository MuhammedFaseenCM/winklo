import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/submit_leaderboard_time.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../../leaderboard/cubit/leaderboard_cubit.dart';
import '../../leaderboard/cubit/leaderboard_state.dart';
import '../../leaderboard/logic/mini_leaderboard_slice.dart';
import '../../leaderboard/view/widgets/leaderboard_row.dart';

class MiniLeaderboardPanel extends StatelessWidget {
  const MiniLeaderboardPanel({
    super.key,
    required this.gameId,
    this.timeSeconds = 0,
  });

  final String gameId;
  final int timeSeconds;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
        initialGameId: gameId,
      ),
      child: _MiniLeaderboardPanelBody(
        gameId: gameId,
        timeSeconds: timeSeconds,
      ),
    );
  }
}

class _MiniLeaderboardPanelBody extends StatelessWidget {
  const _MiniLeaderboardPanelBody({
    required this.gameId,
    required this.timeSeconds,
  });

  final String gameId;
  final int timeSeconds;

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _signInAndSync(BuildContext context) async {
    final ok = await showSignInSheet(context);
    if (!ok || !context.mounted) return;
    if (timeSeconds <= 0) return;
    try {
      await context.read<SubmitLeaderboardTime>()(
        gameId: gameId,
        timeSeconds: timeSeconds,
      );
    } catch (_) {
      // Best-effort remote sync; signed-in UI still shows live board.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: ZipColors.emberGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: ZipColors.emberGlow.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 20,
                color: ZipColors.onInk,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppStrings.leaderboardTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
            builder: (context, state) {
              final signedIn = context.watch<AuthCubit>().isSignedIn;
              if (!signedIn) {
                return CenteredMessageBody(
                  message: AppStrings.leaderboardSignInHint,
                  actionLabel: AppStrings.signInWithGoogle,
                  onAction: () => _signInAndSync(context),
                );
              }
              switch (state.status) {
                case LeaderboardStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case LeaderboardStatus.failure:
                  return CenteredMessageBody(
                    message: state.error ?? AppStrings.leaderboardFailed,
                    actionLabel: AppStrings.retry,
                    onAction: () => context.read<LeaderboardCubit>().retry(),
                  );
                case LeaderboardStatus.ready:
                  if (state.entries.isEmpty) {
                    return const CenteredMessageBody(
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
