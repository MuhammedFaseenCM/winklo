import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/centered_message_body.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../data/clients/remote_config_client.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../domain/entities/leaderboard_period.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/league_repository.dart';
import '../../../domain/usecases/watch_leaderboard.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/view/ensure_signed_in_for_play.dart';
import '../../auth/view/sign_in_sheet.dart';
import '../cubit/leaderboard_cubit.dart';
import '../cubit/leaderboard_state.dart';
import '../logic/board_calendar.dart';
import '../logic/board_layout.dart';
import 'widgets/leaderboard_board_sheet.dart';
import 'widgets/leaderboard_board_view.dart';
import 'widgets/leaderboard_filter_row.dart';
import 'widgets/leaderboard_game_tabs.dart';
import 'widgets/leaderboard_scope_sheet.dart';
import 'widgets/leaderboard_shimmer.dart';
import 'widgets/leaderboard_table.dart';
import 'widgets/player_card_sheet.dart';

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
        leagueRepository: context.read<LeagueRepository?>(),
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

  /// The last `league` query applied, so coming back to the tab doesn't undo
  /// a later pick in the scope bar.
  String? _appliedLeagueQuery;

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
    final leagueId = uri.queryParameters['league'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<LeaderboardCubit>();
      cubit.selectGame(gameId);
      // `/leaderboard?league={id}`: that league's board.
      if (leagueId != null && leagueId != _appliedLeagueQuery) {
        cubit.selectLeague(leagueId);
      }
      _appliedLeagueQuery = leagueId;
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
  final GlobalKey _boardHeadKey = GlobalKey();
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
      final cubit = context.read<LeaderboardCubit>();
      if (cubit.state.period != LeaderboardPeriod.allTime) return;
      cubit.selectPeriod(LeaderboardPeriod.daily);
    });
  }

  /// From a scroll notification: a ballistic scroll can start mid-layout,
  /// when the rows can't be measured yet, so then it waits for the frame.
  void _onBoardScrolled(AppLayout layout, int userIndex) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.persistentCallbacks) {
      _checkUserVisibility(layout, userIndex);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkUserVisibility(layout, userIndex);
    });
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

  /// Where your row starts in the board's scroll view.
  double _userTop(int userIndex) {
    final head = _boardHeadKey.currentContext?.findRenderObject();
    final headHeight = head is RenderBox && head.hasSize
        ? head.size.height
        : 0.0;
    final weekly =
        context.read<LeaderboardCubit>().state.period ==
        LeaderboardPeriod.weekly;
    return leaderboardEntryTop(
      index: userIndex,
      headExtent: headHeight + (weekly ? leaderboardTableHeaderHeight : 0),
      rowExtent: leaderboardTableRowHeight,
    );
  }

  bool _isUserReached(AppLayout layout, int userIndex) {
    if (userIndex == -1) return true;

    // The dashboard's SafeArea already keeps the board above the nav dock;
    // only the pinned row covers the bottom of the list.
    final overlayThreshold = leaderboardTableRowHeight + layout.space(10);

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

    final userItemTop = _userTop(userIndex);
    final currentBottom = position.pixels + viewportHeight;

    return currentBottom >= (userItemTop + overlayThreshold);
  }

  void _scrollToUser(int userIndex, AppLayout layout) {
    if (!_scrollController.hasClients) return;
    final targetOffset = (_userTop(userIndex) - 100.0).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pickBoard(BuildContext context) async {
    final cubit = context.read<LeaderboardCubit>();
    final choice = await showLeaderboardBoardSheet(
      context,
      period: cubit.state.period,
      dayId: cubit.state.dayId,
      recentDayIds: cubit.recentDayIds,
      showAllTime: _showAllTimeLeaderboard,
    );
    if (choice == null || !mounted || cubit.isClosed) return;
    // Remote Config may have hidden All-time while the sheet was open.
    if (choice.period == LeaderboardPeriod.allTime &&
        !_showAllTimeLeaderboard) {
      return;
    }
    cubit.selectBoard(choice.period, dayId: choice.dayId);
  }

  Future<void> _pickScope(BuildContext context) async {
    final cubit = context.read<LeaderboardCubit>();
    final router = GoRouter.of(context);
    final choice = await showLeaderboardScopeSheet(
      context,
      leagues: cubit.state.leagues,
      selectedLeagueId: cubit.state.leagueId,
    );
    if (choice == null || !mounted || cubit.isClosed) return;
    if (choice.manageLeagues) {
      unawaited(router.push('/leagues'));
      return;
    }
    cubit.selectLeague(choice.leagueId);
  }

  /// The empty board's message when there's nothing to play for on a past day.
  String? _quietEmptyMessage(LeaderboardState state) {
    if (state.period == LeaderboardPeriod.daily && state.dayId != null) {
      return AppStrings.leaderboardPastDayEmpty;
    }
    return null;
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
      _slideDirection = cubitState.period.index > _previousPeriod.index
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
                      bottom: layout.space(10),
                    ),
                    child: Row(
                      children: [
                        if (GoRouter.of(context).canPop())
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const AppIcon(
                                AppIcons.chevronLeft,
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
                          child: const AppIcon(
                            AppIcons.trophy,
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
                      builder: (context, state) => LeaderboardGameTabs(
                        gameId: state.gameId,
                        onChanged: context.read<LeaderboardCubit>().selectGame,
                      ),
                    ),
                  ),
                  SizedBox(height: layout.space(10)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: layout.space(16)),
                    child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
                      buildWhen: (p, n) =>
                          p.period != n.period ||
                          p.dayId != n.dayId ||
                          p.leagueId != n.leagueId ||
                          p.leagues != n.leagues ||
                          p.currentUid != n.currentUid,
                      builder: (context, state) {
                        final cubit = context.read<LeaderboardCubit>();
                        final league = state.league;
                        final canPickScope =
                            state.currentUid != null &&
                            context.read<LeagueRepository?>() != null;
                        return LeaderboardFilterRow(
                          boardIcon: switch (state.period) {
                            LeaderboardPeriod.daily => AppIcons.today,
                            LeaderboardPeriod.weekly => AppIcons.week,
                            LeaderboardPeriod.allTime => AppIcons.medal,
                          },
                          boardLabel: leaderboardBoardLabel(
                            period: state.period,
                            dayId: state.dayId,
                            recentDayIds: cubit.recentDayIds,
                          ),
                          onBoardTap: () => _pickBoard(context),
                          scopeIcon: league == null
                              ? AppIcons.globe
                              : AppIcons.group,
                          scopeLabel: canPickScope
                              ? (league?.name ??
                                    AppStrings.leaderboardScopeEveryone)
                              : null,
                          onScopeTap: () => _pickScope(context),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: layout.space(10)),
                  Expanded(
                    child: _LeaderboardSlideSwitch(
                      switchKey:
                          '${cubitState.gameId}_${cubitState.period}_'
                          '${cubitState.dayId}_${cubitState.leagueId}',
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
                                message: AppStrings.leaderboardFailed,
                                actionLabel: AppStrings.retry,
                                onAction: () =>
                                    context.read<LeaderboardCubit>().retry(),
                              );
                            case LeaderboardStatus.ready:
                              final quietEmpty = _quietEmptyMessage(state);
                              if (state.entries.isEmpty && quietEmpty != null) {
                                return CenteredMessageBody(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 24,
                                  ),
                                  message: quietEmpty,
                                );
                              }
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
                                    child: const AppIcon(
                                      AppIcons.trophy,
                                      size: 34,
                                      color: ZipColors.ember,
                                    ),
                                  ),
                                  iconSpacing: 20,
                                  message: state.leagueId != null
                                      ? AppStrings.leaderboardLeagueEmpty
                                      : state.period == LeaderboardPeriod.weekly
                                      ? AppStrings.leaderboardWeeklyEmpty
                                      : AppStrings.leaderboardEmpty,
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
                                      label: AppStrings.leaderboardPlayGame(
                                        gameTitle,
                                      ),
                                      icon: AppIcons.play,
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
                              // Under the card; the shell's SafeArea already
                              // ends above the nav dock.
                              final bottomGap = hasNavDock
                                  ? layout.space(8)
                                  : layout.pagePadding.bottom;
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

                              final ahead = userIndex > 0
                                  ? state.entries[userIndex - 1]
                                  : null;
                              final behindSeconds = ahead == null
                                  ? null
                                  : leaderboardGapSeconds(
                                      entry: userEntry!,
                                      ahead: ahead,
                                      period: state.period,
                                    );

                              return Stack(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      bottomGap,
                                    ),
                                    child:
                                        NotificationListener<
                                          ScrollNotification
                                        >(
                                          onNotification: (_) {
                                            _onBoardScrolled(layout, userIndex);
                                            return false;
                                          },
                                          child: LeaderboardBoardView(
                                            listKey: _listKey,
                                            headKey: _boardHeadKey,
                                            userKey: _userRowKey,
                                            controller: _scrollController,
                                            entries: state.entries,
                                            period: state.period,
                                            gameId: state.gameId,
                                            currentUid: state.currentUid,
                                            // Kept while the pin can show, so
                                            // hiding it doesn't move the rows.
                                            bottomPadding:
                                                (userEntry != null &&
                                                        !inInitialList
                                                    ? 64.0
                                                    : 0.0) +
                                                (showSignInFab ? 80.0 : 0.0),
                                            onTapEntry: (entry) =>
                                                showPlayerCardSheet(
                                                  context,
                                                  entry: entry,
                                                  gameId: state.gameId,
                                                  period: state.period,
                                                  isYou:
                                                      entry.uid ==
                                                      state.currentUid,
                                                ),
                                          ),
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
                                                    padding:
                                                        EdgeInsets.fromLTRB(
                                                          12,
                                                          layout.space(10),
                                                          12,
                                                          bottomGap +
                                                              layout.space(6),
                                                        ),
                                                    child: _PinnedUserRow(
                                                      entry: userEntry,
                                                      subtitle:
                                                          behindSeconds == null
                                                          ? null
                                                          : AppStrings.leaderboardBehind(
                                                              AppStrings.formatPlayTime(
                                                                behindSeconds,
                                                              ),
                                                              ahead!.rank,
                                                            ),
                                                      period: state.period,
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
                      child: Text(AppStrings.signInWithGoogle),
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
    required this.period,
    required this.gameId,
    required this.onTap,
    this.subtitle,
  });

  final LeaderboardEntry entry;

  /// "0:05 behind #13" under your name, when there's a gap to show.
  final String? subtitle;
  final LeaderboardPeriod period;
  final String gameId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: ZipColors.wall,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ZipColors.ember.withValues(alpha: 0.5)),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: LeaderboardTableRow(
                  entry: entry,
                  period: period,
                  gameId: gameId,
                  isYou: true,
                  showDivider: false,
                  subtitle: subtitle,
                  onTap: onTap,
                ),
              ),
              Positioned(
                top: -8,
                right: 16,
                child: IgnorePointer(
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
                        const AppIcon(
                          AppIcons.locate,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppStrings.leaderboardYourRank,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
