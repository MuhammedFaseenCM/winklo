import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/zip_ui.dart';
import '../../domain/game_ids.dart';
import '../../domain/repositories/analytics_repository.dart';
import 'results_args.dart';
import 'view/mini_leaderboard_panel.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.args});

  final ResultsArgs args;

  Future<void> _logAction(BuildContext context, String action) {
    final gameId = args.gameId;
    if (gameId == null || gameId.isEmpty) return Future<void>.value();
    return context.read<AnalyticsRepository>().logResultsAction(
      gameId: gameId,
      action: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (args.gameId) {
      case GameIds.zip:
        return _miniLeaderboardScaffold(
          gameId: GameIds.zip,
          timeSeconds: args.timeSeconds,
        );
      case GameIds.pathWords:
        return _miniLeaderboardScaffold(
          gameId: GameIds.pathWords,
          timeSeconds: args.timeSeconds,
        );
      default:
        break;
    }

    final title = args.title;
    final subtitle = args.subtitle;
    final time = args.timeSeconds;
    final improved = args.improved;
    final replayDaily = args.replayDaily;
    final replayId = args.replayLevelId;
    final nextId = args.nextLevelId;
    final points = args.points;

    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const ZipMark(size: 72)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: ZipColors.inkSoft),
                  ).animate().fadeIn(delay: 120.ms),
                ],
                const SizedBox(height: 28),
                Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: ZipColors.cardGradient,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: ZipColors.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _formatTime(time),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  color: ZipColors.ember,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: ZipColors.emberGlow.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'time',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: ZipColors.inkSoft,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                          ),
                          if (points != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x14FFFFFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x1AFFFFFF),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$points',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: ZipColors.onInk,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  Text(
                                    'points',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: ZipColors.inkSoft,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (improved) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: ZipColors.successSoft,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: ZipColors.success.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ZipColors.success.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: ZipColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppStrings.newPersonalBest,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: ZipColors.success,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (args.currentStreak != null &&
                              args.currentStreak! > 0) ...[
                            const SizedBox(height: 16),
                            ZipHudPill(
                              icon: Icons.local_fire_department_rounded,
                              label: AppStrings.streakLabel(
                                args.currentStreak!,
                              ),
                              emphasize: true,
                            ),
                            if (args.longestStreak != null &&
                                args.longestStreak! > 0) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.longestStreakLabel(
                                  args.longestStreak!,
                                ),
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: ZipColors.inkSoft),
                              ),
                            ],
                          ],
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 160.ms, duration: 450.ms)
                    .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                if (replayDaily)
                  Text(
                    AppStrings.newPuzzleUnlocksTomorrow,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: ZipColors.inkSoft),
                  ),
                const Spacer(),
                if (!replayDaily &&
                    (replayId != null || args.replayRoute != null))
                  ZipPrimaryButton(
                    label: AppStrings.playAgain,
                    icon: Icons.refresh_rounded,
                    onPressed: () async {
                      await _logAction(context, 'play_again');
                      if (!context.mounted) return;
                      final route =
                          args.replayRoute ??
                          (replayId != null ? '/zip' : null);
                      if (route != null) {
                        context.pushReplacement(route);
                      }
                    },
                  ).animate().fadeIn(delay: 220.ms)
                else if (replayDaily)
                  ZipPrimaryButton(
                    label: AppStrings.backHome,
                    icon: Icons.home_rounded,
                    onPressed: () async {
                      await _logAction(context, 'home');
                      if (!context.mounted) return;
                      context.go('/');
                    },
                  ).animate().fadeIn(delay: 220.ms),
                if (nextId != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await _logAction(context, 'play_other');
                      if (!context.mounted) return;
                      context.pushReplacement('/zip');
                    },
                    child: const Text('Next puzzle'),
                  ),
                ],
                if (!replayDaily) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () async {
                      await _logAction(context, 'home');
                      if (!context.mounted) return;
                      context.go('/');
                    },
                    child: Text(AppStrings.backHome),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _miniLeaderboardScaffold({
    required String gameId,
    required int timeSeconds,
  }) {
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: MiniLeaderboardPanel(
              gameId: gameId,
              timeSeconds: timeSeconds,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
