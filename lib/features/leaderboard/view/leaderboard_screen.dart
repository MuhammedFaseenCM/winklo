import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/leaderboard_cubit.dart';
import '../cubit/leaderboard_state.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, this.initialGameId = GameIds.zip});

  final String initialGameId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
        initialGameId: initialGameId == GameIds.pathWords
            ? GameIds.pathWords
            : GameIds.zip,
      ),
      child: const _LeaderboardView(),
    );
  }
}

class _LeaderboardView extends StatelessWidget {
  const _LeaderboardView();

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: layout.pagePadding.copyWith(bottom: 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: ZipColors.onInk,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        AppStrings.leaderboardTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: ZipColors.onInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
                child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
                  buildWhen: (p, n) => p.gameId != n.gameId,
                  builder: (context, state) {
                    return SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: GameIds.zip,
                          label: Text(AppStrings.zipTitle),
                        ),
                        ButtonSegment(
                          value: GameIds.pathWords,
                          label: Text(AppStrings.pathWordsTitle),
                        ),
                      ],
                      selected: {state.gameId},
                      onSelectionChanged: (values) {
                        context.read<LeaderboardCubit>().selectGame(
                          values.first,
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: layout.space(12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
                child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
                  buildWhen: (p, n) => p.period != n.period,
                  builder: (context, state) {
                    return SegmentedButton<LeaderboardPeriod>(
                      segments: const [
                        ButtonSegment(
                          value: LeaderboardPeriod.daily,
                          label: Text(AppStrings.leaderboardDaily),
                        ),
                        ButtonSegment(
                          value: LeaderboardPeriod.allTime,
                          label: Text(AppStrings.leaderboardAllTime),
                        ),
                      ],
                      selected: {state.period},
                      onSelectionChanged: (values) {
                        context.read<LeaderboardCubit>().selectPeriod(
                          values.first,
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: layout.space(8)),
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
                          onAction: () =>
                              context.read<LeaderboardCubit>().retry(),
                        );
                      case LeaderboardStatus.ready:
                        if (state.entries.isEmpty) {
                          return const _MessageBody(
                            message: AppStrings.leaderboardEmpty,
                          );
                        }
                        return ListView.separated(
                          padding: layout.pagePadding,
                          itemCount: state.entries.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: layout.space(8)),
                          itemBuilder: (context, index) {
                            final entry = state.entries[index];
                            return _LeaderboardRow(
                              entry: entry,
                              timeLabel: _formatTime(entry.timeSeconds),
                              isYou: entry.uid == state.currentUid,
                            );
                          },
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.timeLabel,
    required this.isYou,
  });

  final LeaderboardEntry entry;
  final String timeLabel;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final photoUrl = entry.photoUrl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isYou ? ZipColors.emberSoft : ZipColors.wall,
        borderRadius: BorderRadius.circular(14),
        border: isYou
            ? Border.all(color: ZipColors.ember.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: ZipColors.mistDeep,
            backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl == null || photoUrl.isEmpty
                ? Text(
                    entry.displayName.isNotEmpty
                        ? entry.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: ZipColors.onInk),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: ZipColors.onInk),
                ),
                if (isYou)
                  Text(
                    AppStrings.youLabel,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: ZipColors.ember),
                  ),
              ],
            ),
          ),
          Text(
            timeLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ZipColors.onInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
