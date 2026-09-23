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
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/view/sign_in_sheet.dart';
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
    final path = _router?.state.uri.path;
    if (path == null) return;
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

  String _formatBestTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final bestTime = state.bestTimeSeconds;
        final zipCleared =
            !DevFlags.zipOnlyTesting &&
            (state.bestPoints > 0 || bestTime != null);
        final pathWordsBestTime = state.pathWordsBestTimeSeconds;
        final pathWordsCleared =
            state.pathWordsBestPoints > 0 || pathWordsBestTime != null;
        final isSoftUpdate = state.updateStatus == AppUpdateStatus.soft;
        final isForcedUpdate = state.updateStatus == AppUpdateStatus.forced;

        Future<bool> ensureSignedInForPlay() async {
          final auth = context.read<AuthCubit>();
          if (auth.isSignedIn) return true;
          final ok = await showSignInSheet(context);
          return ok && context.mounted && context.read<AuthCubit>().isSignedIn;
        }

        Future<void> openZip() async {
          if (!await ensureSignedInForPlay()) return;
          if (!context.mounted) return;
          final cubit = context.read<HomeCubit>();
          await cubit.openGame(GameIds.zip);
          if (!context.mounted) return;
          await context.push('/zip');
          if (!cubit.isClosed) await cubit.load();
        }

        Future<void> openPathWords() async {
          if (!await ensureSignedInForPlay()) return;
          if (!context.mounted) return;
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
                                longestStreak: state.longestStreak,
                                cleared: zipCleared,
                                bestTimeLabel: zipCleared && bestTime != null
                                    ? AppStrings.bestTimeLabel(
                                        _formatBestTime(bestTime),
                                      )
                                    : null,
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
                                  longestStreak: state.pathWordsLongestStreak,
                                  cleared: pathWordsCleared,
                                  bestTimeLabel:
                                      pathWordsCleared &&
                                          pathWordsBestTime != null
                                      ? AppStrings.bestTimeLabel(
                                          _formatBestTime(pathWordsBestTime),
                                        )
                                      : null,
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
              Text(
                AppStrings.appTitle,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: ZipColors.onInk,
                  height: 1,
                  fontSize: layout.isCompact ? 28 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: layout.space(4)),
              Text(
                AppStrings.homeTagline,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: ZipColors.inkSoft),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: AppStrings.leaderboardTitle,
          onPressed: () => context.push('/leaderboard'),
          icon: const Icon(Icons.emoji_events_outlined, color: ZipColors.onInk),
        ),
        const _AuthAvatarButton(),
      ],
    );
  }
}

class _AuthAvatarButton extends StatelessWidget {
  const _AuthAvatarButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        if (user == null) {
          return IconButton(
            tooltip: AppStrings.signInWithGoogle,
            onPressed: () => showSignInSheet(context),
            icon: const Icon(Icons.login, color: ZipColors.onInk),
          );
        }
        final photoUrl = user.photoUrl;
        return PopupMenuButton<String>(
          tooltip: user.displayName,
          onSelected: (value) {
            if (value == 'sign_out') {
              unawaited(context.read<AuthCubit>().signOut());
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'sign_out', child: Text(AppStrings.signOut)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: ZipColors.mistDeep,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: ZipColors.onInk,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
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
    this.longestStreak = 0,
    this.cleared = false,
    this.bestTimeLabel,
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
  final int longestStreak;
  final bool cleared;
  final String? bestTimeLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final layout = AppLayout.of(context);
    final titleStyle = layout.isCompact
        ? textTheme.titleLarge
        : textTheme.headlineMedium;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZipColors.wall,
        borderRadius: BorderRadius.circular(layout.space(24)),
        border: Border.all(color: ZipColors.outlineQuiet),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: layout.space(28),
            offset: Offset(0, layout.space(14)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(layout.space(24)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: accent,
                child: SizedBox(width: layout.space(6)),
              ),
              Expanded(
                child: Padding(
                  padding: layout.tilePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.space(10),
                              vertical: layout.space(6),
                            ),
                            decoration: BoxDecoration(
                              color: accentSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppStrings.today,
                              style: textTheme.labelLarge?.copyWith(
                                color: accent,
                              ),
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
                                    icon: Icons.local_fire_department_rounded,
                                    label: AppStrings.streakLabel(streak),
                                    emphasize: true,
                                  ),
                                if (cleared)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: layout.space(18),
                                        color: ZipColors.success,
                                      ),
                                      SizedBox(width: layout.space(6)),
                                      Text(
                                        AppStrings.cleared,
                                        style: textTheme.labelLarge?.copyWith(
                                          color: ZipColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isOnFreeze) ...[
                        SizedBox(height: layout.space(10)),
                        Text(
                          AppStrings.streakProtectedLabel,
                          style: textTheme.labelMedium?.copyWith(color: accent),
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
                          ),
                          SizedBox(width: layout.space(12)),
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
                                  ),
                                  maxLines: layout.isCompact ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (longestStreak > 0 || bestTimeLabel != null) ...[
                        SizedBox(height: layout.space(10)),
                        Text(
                          [
                            ?bestTimeLabel,
                            if (longestStreak > 0)
                              AppStrings.longestStreakLabel(longestStreak),
                          ].join('  ·  '),
                          style: textTheme.labelMedium?.copyWith(
                            color: ZipColors.inkSoft,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(
                        height: layout.space(layout.isCompact ? 12 : 18),
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
  });

  final String assetPath;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: ZipColors.outlineQuiet),
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
