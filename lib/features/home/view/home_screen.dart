import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
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
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import 'widgets/home_force_update_overlay.dart';
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
    final router = GoRouter.of(context);
    if (identical(_router, router)) return;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _router = router;
    _lastPath = router.state.uri.path;
    _router!.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        final isForcedUpdate = state.updateStatus == AppUpdateStatus.forced;

        Future<void> openZip() async {
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.zip);
          if (!context.mounted) return;
          await context.push('/zip');
          if (!cubit.isClosed) await cubit.load();
        }

        Future<void> openPathWords() async {
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.pathWords);
          if (!context.mounted) return;
          await context.push('/path-words');
          if (!cubit.isClosed) await cubit.load();
        }

        return Scaffold(
          body: ZipAtmosphere(
            child: Stack(
              fit: StackFit.expand,
              children: [
                SafeArea(
                  child: Builder(
                    builder: (context) {
                      final layout = AppLayout.of(context);
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: layout.pagePadding,
                        children: [
                          const _HomeHeader()
                              .animate()
                              .fadeIn(duration: 450.ms)
                              .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                          if (isSoftUpdate) ...[
                            SizedBox(height: layout.space(16)),
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
                          _DailyGameTile(
                                accent: ZipColors.ember,
                                accentSoft: ZipColors.emberSoft,
                                iconAsset: _GameTileAssets.zip,
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
                                streak: state.currentStreak,
                                isOnFreeze: state.isOnFreeze,
                                cleared: zipCleared,
                              )
                              .animate()
                              .fadeIn(delay: 80.ms, duration: 450.ms)
                              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                          if (!DevFlags.zipOnlyTesting) ...[
                            SizedBox(height: layout.tileGap),
                            _DailyGameTile(
                                  accent: ZipColors.sky,
                                  accentSoft: ZipColors.skySoft,
                                  iconAsset: _GameTileAssets.pathWords,
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
                                  streak: state.pathWordsCurrentStreak,
                                  isOnFreeze: state.pathWordsIsOnFreeze,
                                  cleared: pathWordsCleared,
                                )
                                .animate()
                                .fadeIn(delay: 160.ms, duration: 450.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOutCubic),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                if (isForcedUpdate)
                  HomeForceUpdateOverlay(
                    currentLabel: state.updateCurrentLabel,
                    requiredLabel: state.updateRequiredLabel,
                    onUpdate: () => context.read<HomeCubit>().openStore(),
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
        SizedBox(width: layout.space(14)),
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
                            fontSize: layout.isCompact ? 24 : 28,
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
              SizedBox(height: layout.space(5)),
              Text(
                AppStrings.homeTagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ZipColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyGameTile extends StatelessWidget {
  const _DailyGameTile({
    required this.accent,
    required this.accentSoft,
    required this.iconAsset,
    required this.title,
    required this.tagline,
    required this.playLabel,
    this.onPlay,
    this.onViewResult,
    this.playBackground,
    this.streak = 0,
    this.isOnFreeze = false,
    this.cleared = false,
  });

  final Color accent;
  final Color accentSoft;
  final String iconAsset;
  final String title;
  final String tagline;
  final String playLabel;
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
    final titleStyle = layout.isCompact
        ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(layout.space(24)),
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
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: layout.space(28),
            offset: Offset(0, layout.space(12)),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: layout.space(30),
            spreadRadius: -4,
            offset: Offset(0, layout.space(4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(layout.space(24)),
        child: Stack(
          children: [
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.16),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: layout.space(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accent.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: layout.tilePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: layout.space(10),
                                  vertical: layout.space(5),
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
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: layout.space(6)),
                                    Text(
                                      AppStrings.today,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: layout.space(8)),
                              Expanded(
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: layout.space(8),
                                  runSpacing: layout.space(8),
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (streak > 0)
                                      ZipHudPill(
                                        icon:
                                            Icons.local_fire_department_rounded,
                                        label: AppStrings.streakLabel(streak),
                                        emphasize: true,
                                        compact: true,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isOnFreeze) ...[
                            SizedBox(height: layout.space(10)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ZipColors.skySoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ZipColors.sky.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                AppStrings.streakProtectedLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: ZipColors.sky,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(
                            height: layout.space(layout.isCompact ? 12 : 16),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _GameTileArt(
                                assetPath: iconAsset,
                                semanticLabel: title,
                                size: layout.tileArtSize,
                                accentColor: accent,
                              ),
                              SizedBox(width: layout.space(14)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: titleStyle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: layout.space(4)),
                                    Text(
                                      tagline,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: ZipColors.inkSoft,
                                        height: 1.3,
                                      ),
                                      maxLines: layout.isCompact ? 2 : 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Best time / longest-streak chip hidden for now.
                          SizedBox(
                            height: layout.space(layout.isCompact ? 14 : 18),
                          ),
                          if (cleared)
                            ZipPrimaryButton(
                              label: AppStrings.result,
                              icon: Icons.emoji_events_rounded,
                              backgroundColor: playBackground,
                              onPressed: onViewResult,
                            )
                          else
                            ZipPrimaryButton(
                              label: playLabel,
                              icon: Icons.play_arrow_rounded,
                              backgroundColor: playBackground,
                              onPressed: onPlay,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _GameTileAssets {
  static const zip = 'assets/games/zip_tile.png';
  static const pathWords = 'assets/games/path_words_tile.png';
}

class _GameTileArt extends StatelessWidget {
  const _GameTileArt({
    required this.assetPath,
    required this.semanticLabel,
    required this.size,
    this.accentColor,
  });

  final String assetPath;
  final String semanticLabel;
  final double size;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: (accentColor ?? ZipColors.outlineQuiet).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          if (accentColor != null)
            BoxShadow(
              color: accentColor!.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: -2,
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
