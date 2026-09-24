import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/leaderboard_cubit.dart';
import '../cubit/leaderboard_state.dart';
import 'widgets/leaderboard_row.dart';

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
      child: const _RouteGameSync(child: _LeaderboardView()),
    );
  }
}

/// IndexedStack keeps [LeaderboardCubit] alive, so a later
/// `go('/leaderboard?game=...')` must call [LeaderboardCubit.selectGame].
class _RouteGameSync extends StatefulWidget {
  const _RouteGameSync({required this.child});

  final Widget child;

  @override
  State<_RouteGameSync> createState() => _RouteGameSyncState();
}

class _RouteGameSyncState extends State<_RouteGameSync> {
  GoRouter? _router;
  String? _appliedLocation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_applyRouteGame);
      _router = router;
      router.routerDelegate.addListener(_applyRouteGame);
    }
    _applyRouteGame();
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_applyRouteGame);
    super.dispose();
  }

  void _applyRouteGame() {
    if (!mounted) return;
    final uri = _router?.routerDelegate.currentConfiguration.uri;
    if (uri == null) return;
    final location = uri.toString();
    final previous = _appliedLocation;
    _appliedLocation = location;
    if (uri.path != '/leaderboard') return;
    final previousUri = previous == null ? null : Uri.tryParse(previous);
    final sameLeaderboard =
        previousUri?.path == '/leaderboard' && previous == location;
    if (sameLeaderboard) return;
    final game = uri.queryParameters['game'];
    final gameId = game == GameIds.pathWords ? GameIds.pathWords : GameIds.zip;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LeaderboardCubit>().selectGame(gameId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
                    if (GoRouter.of(context).canPop())
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
                            return LeaderboardRow(
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
