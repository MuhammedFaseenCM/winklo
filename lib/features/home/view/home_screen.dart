import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/static_assets_config.dart';
import '../../../core/dev_flags.dart';
import '../../../core/lifecycle/progress_sync_lifecycle.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/entities/app_update_decision.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/app_update_repository.dart';
import '../../../domain/usecases/check_app_update.dart';
import '../../../domain/usecases/get_best_points.dart';
import '../../../domain/usecases/get_best_time_seconds.dart';
import '../../../domain/usecases/get_streak.dart';
import '../../../domain/usecases/schedule_engagement_notifications.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/zip_level_repository.dart';
import '../../auth/view/ensure_signed_in_for_play.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import 'widgets/home_update_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const permissionPromptedKey = 'notif_permission_prompted';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit(
        getBestPoints: context.read<GetBestPoints>(),
        getBestTimeSeconds: context.read<GetBestTimeSeconds>(),
        getStreak: context.read<GetStreak>(),
        analytics: context.read<AnalyticsRepository>(),
        checkAppUpdate: context.read<CheckAppUpdate>(),
        appUpdateRepository: context.read<AppUpdateRepository>(),
        scheduleEngagementNotifications: context
            .read<ScheduleEngagementNotifications>(),
        zipLevelRepository: context.read<ZipLevelRepository>(),
        playPeriod: DevFlags.playPeriod,
      )..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with WidgetsBindingObserver {
  GoRouter? _router;
  String? _lastPath;
  StreamSubscription<void>? _restoredSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeRequestNotificationPermission());
    });
  }

  Future<void> _maybeRequestNotificationPermission() async {
    if (!mounted) return;
    final prefs = context.read<SharedPreferences>();
    if (prefs.getBool(HomeScreen.permissionPromptedKey) ?? false) return;
    await prefs.setBool(HomeScreen.permissionPromptedKey, true);
    if (!mounted) return;
    await context.read<NotificationRepository>().requestPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload locks / bests / streaks after a sync restored remote progress.
    // Nullable read: widget tests may not provide the lifecycle.
    _restoredSub ??= context.read<ProgressSyncLifecycle?>()?.restored.listen(
      (_) => _onProgressRestored(),
    );
    final router = GoRouter.of(context);
    if (identical(_router, router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _lastPath = router.state.uri.path;
    _router!.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    unawaited(_restoredSub?.cancel());
    _restoredSub = null;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onProgressRestored() {
    if (!mounted) return;
    final cubit = context.read<HomeCubit>();
    if (!cubit.isClosed) unawaited(cubit.load());
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final router = _router;
    if (router == null) return;
    // Guard empty match lists (e.g. a stray pop emptied the branch stack).
    if (router.routerDelegate.currentConfiguration.isEmpty) return;
    final path = router.state.uri.path;
    final returnedHome = path == '/' && _lastPath != null && _lastPath != '/';
    _lastPath = path;
    if (returnedHome) {
      context.read<HomeCubit>().load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<HomeCubit>().recheckUpdate();
    context.read<HomeCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final bestTime = state.bestTimeSeconds;
        final zipCleared =
            !DevFlags.zipOnlyTesting &&
            (state.bestPoints > 0 || bestTime != null);
        final pathWordsCleared =
            state.pathWordsBestPoints > 0 ||
            state.pathWordsBestTimeSeconds != null;
        final isSoftUpdate = state.updateStatus == AppUpdateStatus.soft;

        Future<void> openZip() async {
          final ok = await ensureSignedInForPlay(context);
          if (!ok || !context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.zip);
          if (!context.mounted) return;
          await context.push('/zip');
          if (!cubit.isClosed) await cubit.load();
        }

        Future<void> openPathWords() async {
          final ok = await ensureSignedInForPlay(context);
          if (!ok || !context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.pathWords);
          if (!context.mounted) return;
          await context.push('/path-words');
          if (!cubit.isClosed) await cubit.load();
        }

        Future<void> openSudoku() async {
          final ok = await ensureSignedInForPlay(context);
          if (!ok || !context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.sudoku);
          if (!context.mounted) return;
          await context.push('/sudoku');
          if (!cubit.isClosed) await cubit.load();
        }

        final sudokuCleared =
            state.sudokuBestPoints > 0 || state.sudokuBestTimeSeconds != null;
        final gameTiles = <Widget>[
          _DailyGameTile(
                accent: ZipColors.ember,
                accentSoft: ZipColors.emberSoft,
                imageUrl: _GameTileAssets.zip,
                title: AppStrings.zipTitle,
                tagline: AppStrings.zipTagline,
                playLabel: AppStrings.playTodaysZip,
                onPlay: zipCleared
                    ? null
                    : () {
                        openZip();
                      },
                onViewResult: zipCleared
                    ? () {
                        openZip();
                      }
                    : null,
                onLeaderboard: () {
                  context.go('/leaderboard?game=${GameIds.zip}');
                },
                streak: state.currentStreak,
                isOnFreeze: state.isOnFreeze,
                cleared: zipCleared,
              )
              .animate()
              .fadeIn(delay: 80.ms, duration: 450.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          if (!DevFlags.zipOnlyTesting) ...[
            _DailyGameTile(
                  accent: ZipColors.sky,
                  accentSoft: ZipColors.skySoft,
                  imageUrl: _GameTileAssets.pathWords,
                  title: AppStrings.pathWordsTitle,
                  tagline: AppStrings.pathWordsTagline,
                  playLabel: AppStrings.playTodaysPathWords,
                  playBackground: ZipColors.skyDeep,
                  onPlay: pathWordsCleared
                      ? null
                      : () {
                          openPathWords();
                        },
                  onViewResult: pathWordsCleared
                      ? () {
                          openPathWords();
                        }
                      : null,
                  onLeaderboard: () {
                    context.go('/leaderboard?game=${GameIds.pathWords}');
                  },
                  streak: state.pathWordsCurrentStreak,
                  isOnFreeze: state.pathWordsIsOnFreeze,
                  cleared: pathWordsCleared,
                )
                .animate()
                .fadeIn(delay: 160.ms, duration: 450.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),
            _DailyGameTile(
                  accent: ZipColors.success,
                  accentSoft: ZipColors.successSoft,
                  imageUrl: _GameTileAssets.sudoku,
                  title: AppStrings.sudokuTitle,
                  tagline: AppStrings.sudokuTagline,
                  playLabel: AppStrings.playTodaysSudoku,
                  playBackground: const Color(0xFF059669),
                  onPlay: sudokuCleared
                      ? null
                      : () {
                          openSudoku();
                        },
                  onViewResult: sudokuCleared
                      ? () {
                          openSudoku();
                        }
                      : null,
                  onLeaderboard: () {
                    context.go('/leaderboard?game=${GameIds.sudoku}');
                  },
                  streak: state.sudokuCurrentStreak,
                  isOnFreeze: state.sudokuIsOnFreeze,
                  cleared: sudokuCleared,
                )
                .animate()
                .fadeIn(delay: 240.ms, duration: 450.ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          ],
        ];

        return Scaffold(
          body: ZipAtmosphere(
            child: Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  child: Builder(
                    builder: (context) {
                      final layout = AppLayout.of(context);
                      return Padding(
                        padding: layout.pagePadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _HomeHeader()
                                .animate()
                                .fadeIn(duration: 450.ms)
                                .slideY(
                                  begin: 0.08,
                                  curve: Curves.easeOutCubic,
                                ),
                            if (isSoftUpdate) ...[
                              SizedBox(height: layout.space(12)),
                              HomeUpdateBanner(
                                currentLabel: state.updateCurrentLabel,
                                requiredLabel: state.updateRequiredLabel,
                                onUpdate: () {
                                  unawaited(
                                    context.read<HomeCubit>().openStore(),
                                  );
                                },
                              ),
                            ],
                            SizedBox(height: layout.sectionGap),
                            Expanded(child: _HomeGamesPane(tiles: gameTiles)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Row(
      children: [
        ZipMark(size: layout.headerMarkSize)
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
        SizedBox(width: layout.space(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      AppStrings.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: ZipColors.onInk,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            fontSize: layout.isCompact ? 22 : 26,
                            letterSpacing: -0.5,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: layout.space(8)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ZipColors.ember.withValues(alpha: 0.22),
                          ZipColors.ember.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ZipColors.ember.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'DAILY',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ZipColors.ember,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: layout.space(4)),
              Text(
                AppStrings.homeTagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ZipColors.inkSoft,
                  fontWeight: FontWeight.w500,
                  fontSize: layout.isCompact ? 13 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Packs game tiles tightly; scrolls only when they cannot fit.
class _HomeGamesPane extends StatelessWidget {
  const _HomeGamesPane({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final gap = layout.tileGap;
    final count = tiles.length;
    if (count == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final gaps = gap * (count - 1);
        final needed = count * layout.homeMinTileHeight + gaps;
        final fits = constraints.maxHeight >= needed;

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(height: gap),
              tiles[i],
            ],
          ],
        );

        if (fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [column, const Spacer()],
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(height: gap),
              tiles[i],
            ],
          ],
        );
      },
    );
  }
}

class _DailyGameTile extends StatelessWidget {
  const _DailyGameTile({
    required this.accent,
    required this.accentSoft,
    required this.imageUrl,
    required this.title,
    required this.tagline,
    required this.playLabel,
    required this.onLeaderboard,
    this.onPlay,
    this.onViewResult,
    this.playBackground,
    this.streak = 0,
    this.isOnFreeze = false,
    this.cleared = false,
  });

  final Color accent;
  final Color accentSoft;
  final String imageUrl;
  final String title;
  final String tagline;
  final String playLabel;
  final VoidCallback onLeaderboard;
  final VoidCallback? onPlay;
  final VoidCallback? onViewResult;
  final Color? playBackground;
  final int streak;
  final bool isOnFreeze;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final layout = AppLayout.of(context);
    final titleStyle = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      fontSize: layout.isCompact ? 16 : 18,
      height: 1.15,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.space(18)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF223048), Color(0xFF1B263B), Color(0xFF131D2E)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: layout.space(18),
            offset: Offset(0, layout.space(8)),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: layout.space(20),
            spreadRadius: -4,
            offset: Offset(0, layout.space(2)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(layout.space(18)),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.14),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: layout.space(5),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: layout.space(5)),
              child: Padding(
                padding: layout.tilePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: layout.space(8),
                            vertical: layout.space(3),
                          ),
                          decoration: BoxDecoration(
                            color: accentSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                ),
                              ),
                              SizedBox(width: layout.space(5)),
                              Text(
                                AppStrings.today,
                                style: textTheme.labelMedium?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOnFreeze) ...[
                          SizedBox(width: layout.space(6)),
                          Flexible(
                            child: Text(
                              AppStrings.streakProtectedLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: ZipColors.sky,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (streak > 0)
                          ZipHudPill(
                            icon: Icons.local_fire_department_rounded,
                            label: AppStrings.streakLabel(streak),
                            emphasize: true,
                            compact: true,
                          ),
                      ],
                    ),
                    SizedBox(height: layout.space(8)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _GameTileArt(
                          imageUrl: imageUrl,
                          semanticLabel: title,
                          size: layout.tileArtSize,
                        ),
                        SizedBox(width: layout.space(12)),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: titleStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: layout.space(2)),
                              Text(
                                tagline,
                                style: textTheme.bodySmall?.copyWith(
                                  color: ZipColors.inkSoft,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: layout.space(10)),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: cleared
                                ? ZipPrimaryButton(
                                    label: AppStrings.result,
                                    icon: Icons.emoji_events_rounded,
                                    backgroundColor: playBackground,
                                    compact: true,
                                    onPressed: onViewResult,
                                  )
                                : ZipPrimaryButton(
                                    label: playLabel,
                                    icon: Icons.play_arrow_rounded,
                                    backgroundColor: playBackground,
                                    compact: true,
                                    onPressed: onPlay,
                                  ),
                          ),
                          SizedBox(width: layout.space(8)),
                          _TileLeaderboardButton(
                            accent: accent,
                            onPressed: onLeaderboard,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileLeaderboardButton extends StatelessWidget {
  const _TileLeaderboardButton({required this.accent, required this.onPressed});

  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final radius = BorderRadius.circular(layout.space(12));

    return Semantics(
      button: true,
      label: AppStrings.leaderboardTitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            width: layout.space(48),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(
              Icons.leaderboard_rounded,
              color: accent,
              size: layout.space(22),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _GameTileAssets {
  static final zip = StaticAssetsConfig.url('games/zip_tile_v3.png');
  static final pathWords = StaticAssetsConfig.url(
    'games/path_words_tile_v2.png',
  );
  static final sudoku = StaticAssetsConfig.url('games/sudoku_tile_v2.png');
}

class _GameTileArt extends StatelessWidget {
  const _GameTileArt({
    required this.imageUrl,
    required this.semanticLabel,
    required this.size,
  });

  final String imageUrl;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: semanticLabel,
        child: AppImage.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: const ColoredBox(color: ZipColors.mistDeep),
          placeholder: const ColoredBox(color: ZipColors.mistDeep),
        ),
      ),
    );
  }
}
