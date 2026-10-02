import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../data/clients/remote_config_client.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/view/ensure_signed_in_for_play.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/leaderboard_cubit.dart';
import '../cubit/leaderboard_state.dart';
import 'widgets/leaderboard_row.dart';
import 'widgets/leaderboard_shimmer.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    this.initialGameId = GameIds.zip,
    this.showAllTimeLeaderboard,
  });

  final String initialGameId;

  /// Test override. Production reads live Remote Config (refreshed on open/resume).
  final bool? showAllTimeLeaderboard;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        watchLeaderboard: context.read<WatchLeaderboard>(),
        authRepository: context.read<AuthRepository>(),
        initialGameId: _resolveLeaderboardGameId(initialGameId),
      ),
      child: _RouteGameSync(
        child: _LeaderboardView(
          showAllTimeLeaderboardOverride: showAllTimeLeaderboard,
        ),
      ),
    );
  }
}

String _resolveLeaderboardGameId(String? game) {
  switch (game) {
    case GameIds.pathWords:
      return GameIds.pathWords;
    case GameIds.sudoku:
      return GameIds.sudoku;
    default:
      return GameIds.zip;
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
    final gameId = _resolveLeaderboardGameId(game);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LeaderboardCubit>().selectGame(gameId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LeaderboardView extends StatefulWidget {
  const _LeaderboardView({this.showAllTimeLeaderboardOverride});

  final bool? showAllTimeLeaderboardOverride;

  @override
  State<_LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<_LeaderboardView>
    with WidgetsBindingObserver {
  String _previousGameId = GameIds.zip;
  LeaderboardPeriod _previousPeriod = LeaderboardPeriod.daily;
  double _slideDirection = 1.0;
  late final ScrollController _scrollController;
  final GlobalKey _userRowKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();
  bool _userReached = false;
  late bool _showAllTimeLeaderboard;
  GoRouter? _router;
  String? _lastRoutePath;

  bool get _usesLiveRemoteConfig =>
      widget.showAllTimeLeaderboardOverride == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _showAllTimeLeaderboard =
        widget.showAllTimeLeaderboardOverride ??
        RemoteConfigClient.instance.showAllTimeLeaderboard;
    _ensureDailyWhenAllTimeHidden();
    if (_usesLiveRemoteConfig) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshShowAllTimeFlag();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_usesLiveRemoteConfig) return;
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteChanged);
      _router = router;
      router.routerDelegate.addListener(_onRouteChanged);
      _lastRoutePath = router.routerDelegate.currentConfiguration.uri.path;
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _usesLiveRemoteConfig) {
      _refreshShowAllTimeFlag();
    }
  }

  void _onRouteChanged() {
    if (!mounted || !_usesLiveRemoteConfig) return;
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    final previous = _lastRoutePath;
    _lastRoutePath = path;
    if (path == '/leaderboard' && previous != '/leaderboard') {
      _refreshShowAllTimeFlag();
    }
  }

  Future<void> _refreshShowAllTimeFlag() async {
    if (!_usesLiveRemoteConfig) return;
    await RemoteConfigClient.instance.refresh();
    if (!mounted) return;
    final next = RemoteConfigClient.instance.showAllTimeLeaderboard;
    if (next == _showAllTimeLeaderboard) return;
    setState(() => _showAllTimeLeaderboard = next);
    _ensureDailyWhenAllTimeHidden();
  }

  void _ensureDailyWhenAllTimeHidden() {
    if (_showAllTimeLeaderboard) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showAllTimeLeaderboard) return;
      context.read<LeaderboardCubit>().selectPeriod(LeaderboardPeriod.daily);
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _checkUserVisibility(AppLayout layout, int userIndex) {
    if (userIndex == -1) {
      if (!_userReached) setState(() => _userReached = true);
      return;
    }
    final isReached = _isUserReached(layout, userIndex);
    if (isReached != _userReached) {
      setState(() => _userReached = isReached);
    }
  }

  bool _isUserReached(AppLayout layout, int userIndex) {
    if (userIndex == -1) return true;

    final hasNavDock = !GoRouter.of(context).canPop();
    final dockOffset = hasNavDock ? (layout.isCompact ? 76.0 : 84.0) : 0.0;
    final pinnedHeight = 64.0 + layout.space(10);
    final overlayThreshold = dockOffset + pinnedHeight;

    final userContext = _userRowKey.currentContext;
    final listContext = _listKey.currentContext;
    if (userContext != null && listContext != null) {
      final userBox = userContext.findRenderObject() as RenderBox?;
      final listBox = listContext.findRenderObject() as RenderBox?;
      if (userBox != null &&
          listBox != null &&
          userBox.hasSize &&
          listBox.hasSize) {
        final userPos = userBox.localToGlobal(Offset.zero, ancestor: listBox);
        return userPos.dy <= (listBox.size.height - overlayThreshold);
      }
    }

    if (!_scrollController.hasClients) {
      return userIndex < 6;
    }

    final position = _scrollController.position;
    final viewportHeight = position.viewportDimension;
    if (viewportHeight <= 0) return userIndex < 6;

    final approxItemHeight = 64.0 + layout.space(8);
    final userItemTop = layout.pagePadding.top + userIndex * approxItemHeight;
    final currentBottom = position.pixels + viewportHeight;

    return currentBottom >= (userItemTop + overlayThreshold);
  }

  void _scrollToUser(int userIndex, AppLayout layout) {
    if (!_scrollController.hasClients) return;
    final approxItemHeight = 64.0 + layout.space(8);
    final targetOffset =
        (layout.pagePadding.top + userIndex * approxItemHeight - 100.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final cubitState = context.watch<LeaderboardCubit>().state;
    if (cubitState.gameId != _previousGameId) {
      _slideDirection = cubitState.gameId == GameIds.pathWords ? 1.0 : -1.0;
      _previousGameId = cubitState.gameId;
      _userReached = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } else if (cubitState.period != _previousPeriod) {
      _slideDirection = cubitState.period == LeaderboardPeriod.allTime
          ? 1.0
          : -1.0;
      _previousPeriod = cubitState.period;
      _userReached = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: layout.pagePadding.copyWith(
                      bottom: layout.space(12),
                    ),
                    child: Row(
                      children: [
                        if (GoRouter.of(context).canPop())
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: ZipColors.onInk,
                                size: 20,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ZipColors.emberSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ZipColors.ember.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: ZipColors.ember,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppStrings.leaderboardTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: ZipColors.onInk,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
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
                        final selectedIndex = switch (state.gameId) {
                          GameIds.pathWords => 1,
                          GameIds.sudoku => 2,
                          _ => 0,
                        };
                        return _LeaderboardPillTrack(
                          selectedIndex: selectedIndex,
                          segmentCount: 3,
                          child: _LeaderboardSegmentBar<String>(
                            selected: state.gameId,
                            onChanged: (value) {
                              context.read<LeaderboardCubit>().selectGame(
                                value,
                              );
                            },
                            segments: const [
                              _LeaderboardSegment(
                                value: GameIds.zip,
                                icon: Icons.bolt_rounded,
                                label: AppStrings.zipTitle,
                              ),
                              _LeaderboardSegment(
                                value: GameIds.pathWords,
                                icon: Icons.route_rounded,
                                label: AppStrings.pathWordsTab,
                              ),
                              _LeaderboardSegment(
                                value: GameIds.sudoku,
                                icon: Icons.grid_on_rounded,
                                label: AppStrings.sudokuTitle,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_showAllTimeLeaderboard) ...[
                    SizedBox(height: layout.space(10)),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: layout.space(16),
                      ),
                      child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
                        buildWhen: (p, n) => p.period != n.period,
                        builder: (context, state) {
                          final selectedIndex =
                              state.period == LeaderboardPeriod.allTime ? 1 : 0;
                          return _LeaderboardPillTrack(
                            selectedIndex: selectedIndex,
                            isSecondary: true,
                            child: _LeaderboardSegmentBar<LeaderboardPeriod>(
                              selected: state.period,
                              isSecondary: true,
                              onChanged: (value) {
                                context.read<LeaderboardCubit>().selectPeriod(
                                  value,
                                );
                              },
                              segments: const [
                                _LeaderboardSegment(
                                  value: LeaderboardPeriod.daily,
                                  icon: Icons.today_rounded,
                                  label: AppStrings.leaderboardDaily,
                                  iconSize: 16,
                                ),
                                _LeaderboardSegment(
                                  value: LeaderboardPeriod.allTime,
                                  icon: Icons.military_tech_rounded,
                                  label: AppStrings.leaderboardAllTime,
                                  iconSize: 16,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(height: layout.space(12)),
                  Expanded(
                    child: _LeaderboardSlideSwitch(
                      switchKey: '${cubitState.gameId}_${cubitState.period}',
                      direction: _slideDirection,
                      child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
                        builder: (context, state) {
                          final auth = context.watch<AuthCubit>().state;
                          if (auth.status == AuthStatus.unknown) {
                            return const LeaderboardShimmer();
                          }
                          switch (state.status) {
                            case LeaderboardStatus.loading:
                              return const LeaderboardShimmer();
                            case LeaderboardStatus.failure:
                              return CenteredMessageBody(
                                message:
                                    state.error ?? AppStrings.leaderboardFailed,
                                actionLabel: AppStrings.retry,
                                onAction: () =>
                                    context.read<LeaderboardCubit>().retry(),
                              );
                            case LeaderboardStatus.ready:
                              if (state.entries.isEmpty) {
                                final gameTitle = switch (state.gameId) {
                                  GameIds.pathWords =>
                                    AppStrings.pathWordsTitle,
                                  GameIds.sudoku => AppStrings.sudokuTitle,
                                  _ => AppStrings.zipTitle,
                                };
                                final gameRoute = switch (state.gameId) {
                                  GameIds.pathWords => '/path-words',
                                  GameIds.sudoku => '/sudoku',
                                  _ => '/zip',
                                };

                                return CenteredMessageBody(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 24,
                                  ),
                                  icon: Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          ZipColors.ember.withValues(
                                            alpha: 0.2,
                                          ),
                                          ZipColors.ember.withValues(
                                            alpha: 0.05,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: ZipColors.ember.withValues(
                                          alpha: 0.4,
                                        ),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ZipColors.ember.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_outlined,
                                      size: 34,
                                      color: ZipColors.ember,
                                    ),
                                  ),
                                  iconSpacing: 20,
                                  message: AppStrings.leaderboardEmpty,
                                  messageStyle: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: ZipColors.onInk,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                  messageSpacing: 24,
                                  action: SizedBox(
                                    width: 220,
                                    child: ZipPrimaryButton(
                                      label: 'Play $gameTitle',
                                      icon: Icons.play_arrow_rounded,
                                      onPressed: () async {
                                        final ok = await ensureSignedInForPlay(
                                          context,
                                        );
                                        if (!ok || !context.mounted) return;
                                        await context.push(gameRoute);
                                        if (context.mounted) {
                                          context
                                              .read<LeaderboardCubit>()
                                              .retry();
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }

                              final userIndex = state.entries.indexWhere(
                                (e) => e.uid == state.currentUid,
                              );
                              final userEntry = userIndex != -1
                                  ? state.entries[userIndex]
                                  : null;
                              final inInitialList =
                                  userIndex != -1 && userIndex < 6;
                              final hasNavDock = !GoRouter.of(context).canPop();
                              final showSignInFab = auth.user == null;
                              final showPinned =
                                  userEntry != null &&
                                  !inInitialList &&
                                  !_userReached;

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _checkUserVisibility(layout, userIndex);
                                }
                              });

                              return Stack(
                                children: [
                                  NotificationListener<ScrollNotification>(
                                    onNotification: (_) {
                                      _checkUserVisibility(layout, userIndex);
                                      return false;
                                    },
                                    child: ListView.separated(
                                      key: _listKey,
                                      controller: _scrollController,
                                      padding: layout.pagePadding.copyWith(
                                        bottom:
                                            layout.pagePadding.bottom +
                                            (hasNavDock ? 88.0 : 0.0) +
                                            (showPinned ? 76.0 : 0.0) +
                                            (showSignInFab ? 80.0 : 0.0),
                                      ),
                                      itemCount: state.entries.length,
                                      separatorBuilder: (_, _) =>
                                          SizedBox(height: layout.space(8)),
                                      itemBuilder: (context, index) {
                                        final entry = state.entries[index];
                                        final isYou =
                                            entry.uid == state.currentUid;
                                        return LeaderboardRow(
                                          key: isYou ? _userRowKey : null,
                                          entry: entry,
                                          timeLabel: _formatTime(
                                            entry.timeSeconds,
                                          ),
                                          isYou: isYou,
                                          showCleanRunChips:
                                              state.period ==
                                              LeaderboardPeriod.daily,
                                          gameId: state.gameId,
                                        );
                                      },
                                    ),
                                  ),
                                  if (userEntry != null && !inInitialList)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: IgnorePointer(
                                        ignoring: !showPinned,
                                        child: AnimatedSlide(
                                          duration: const Duration(
                                            milliseconds: 260,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          offset: showPinned
                                              ? Offset.zero
                                              : const Offset(0, 1.2),
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            opacity: showPinned ? 1.0 : 0.0,
                                            child: showPinned
                                                ? Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.transparent,
                                                          ZipColors.ink
                                                              .withValues(
                                                                alpha: 0.85,
                                                              ),
                                                          ZipColors.ink
                                                              .withValues(
                                                                alpha: 0.98,
                                                              ),
                                                          ZipColors.ink,
                                                        ],
                                                        stops: const [
                                                          0.0,
                                                          0.25,
                                                          0.6,
                                                          1.0,
                                                        ],
                                                      ),
                                                    ),
                                                    padding: EdgeInsets.fromLTRB(
                                                      layout.pagePadding.left,
                                                      layout.space(10),
                                                      layout.pagePadding.right,
                                                      hasNavDock
                                                          ? (layout.isCompact
                                                                ? 76.0
                                                                : 84.0)
                                                          : layout
                                                                .pagePadding
                                                                .bottom,
                                                    ),
                                                    child: _PinnedUserRow(
                                                      entry: userEntry,
                                                      timeLabel: _formatTime(
                                                        userEntry.timeSeconds,
                                                      ),
                                                      showCleanRunChips:
                                                          state.period ==
                                                          LeaderboardPeriod
                                                              .daily,
                                                      gameId: state.gameId,
                                                      onTap: () =>
                                                          _scrollToUser(
                                                            userIndex,
                                                            layout,
                                                          ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final auth = context.watch<AuthCubit>().state;
                  if (auth.status == AuthStatus.unknown || auth.user != null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: FilledButton(
                      key: const Key('leaderboard_sign_in_fab'),
                      onPressed: () => showSignInSheet(context),
                      child: const Text(AppStrings.signInWithGoogle),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardSegment<T> {
  const _LeaderboardSegment({
    required this.value,
    required this.icon,
    required this.label,
    this.iconSize = 18,
  });

  final T value;
  final IconData icon;
  final String label;
  final double iconSize;
}

class _LeaderboardSegmentBar<T> extends StatelessWidget {
  const _LeaderboardSegmentBar({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.isSecondary = false,
  });

  final List<_LeaderboardSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final segment in segments)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(segment.value),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          segment.icon,
                          size: segment.iconSize,
                          color: segment.value == selected
                              ? (isSecondary ? ZipColors.ember : Colors.white)
                              : ZipColors.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            segment.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(
                              fontWeight: segment.value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                              letterSpacing: 0.2,
                              color: segment.value == selected
                                  ? (isSecondary
                                        ? ZipColors.ember
                                        : Colors.white)
                                  : ZipColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LeaderboardPillTrack extends StatelessWidget {
  const _LeaderboardPillTrack({
    required this.selectedIndex,
    required this.child,
    this.segmentCount = 2,
    this.isSecondary = false,
  });

  final int selectedIndex;
  final Widget child;
  final int segmentCount;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSecondary
            ? ZipColors.wall.withValues(alpha: 0.65)
            : ZipColors.wall.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSecondary
              ? ZipColors.outlineQuiet.withValues(alpha: 0.5)
              : ZipColors.outlineQuiet.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: isSecondary
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pillWidth = constraints.maxWidth / segmentCount;
          final pillLeft = selectedIndex * pillWidth;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: pillLeft,
                top: 0,
                bottom: 0,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSecondary ? ZipColors.emberSoft : ZipColors.ember,
                    borderRadius: BorderRadius.circular(12),
                    border: isSecondary
                        ? Border.all(
                            color: ZipColors.ember.withValues(alpha: 0.45),
                            width: 1,
                          )
                        : null,
                    boxShadow: isSecondary
                        ? null
                        : [
                            BoxShadow(
                              color: ZipColors.emberGlow,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                ),
              ),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _LeaderboardSlideSwitch extends StatefulWidget {
  const _LeaderboardSlideSwitch({
    required this.switchKey,
    required this.direction,
    required this.child,
  });

  final String switchKey;
  final double direction;
  final Widget child;

  @override
  State<_LeaderboardSlideSwitch> createState() =>
      _LeaderboardSlideSwitchState();
}

class _LeaderboardSlideSwitchState extends State<_LeaderboardSlideSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = const AlwaysStoppedAnimation<double>(1);
    _slide = const AlwaysStoppedAnimation<Offset>(Offset.zero);
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(_LeaderboardSlideSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.switchKey == widget.switchKey) return;

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(
      begin: Offset(0.08 * widget.direction, 0),
      end: Offset.zero,
    ).animate(curved);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacity,
          child: SlideTransition(position: _slide, child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _PinnedUserRow extends StatelessWidget {
  const _PinnedUserRow({
    required this.entry,
    required this.timeLabel,
    required this.onTap,
    this.showCleanRunChips = false,
    this.gameId,
  });

  final LeaderboardEntry entry;
  final String timeLabel;
  final VoidCallback onTap;
  final bool showCleanRunChips;
  final String? gameId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: ZipColors.ember.withValues(alpha: 0.28),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LeaderboardRow(
                entry: entry,
                timeLabel: timeLabel,
                isYou: true,
                showCleanRunChips: showCleanRunChips,
                gameId: gameId,
              ),
              Positioned(
                top: -8,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    gradient: ZipColors.emberGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: ZipColors.ember.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Your Rank',
                        style: GoogleFonts.lexend(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
