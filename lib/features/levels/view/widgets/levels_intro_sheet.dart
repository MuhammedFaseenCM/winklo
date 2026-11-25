import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/play_mode_route.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../domain/game_ids.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/levels_game_preference_repository.dart';
import '../../../../domain/repositories/levels_intro_repository.dart';
import '../../../../domain/usecases/get_levels_overview.dart';

/// The one-time "New: Levels" card: a row per Levels game with a Play button
/// for its next level, which opens that game's map with the level's sheet
/// up. Reads where each game stands first (briefly; offline it offers
/// Level 1 and opens the map).
Future<void> showLevelsIntro(BuildContext context) async {
  LevelsOverview overview;
  try {
    overview = await context.read<GetLevelsOverview>()().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    overview = const LevelsOverview({});
  }
  if (!context.mounted) return;
  // Seen as it opens (not before the levels load), so a stall before then
  // leaves it for the next visit, and closing the app under it doesn't
  // bring it back.
  final intro = context.read<LevelsIntroRepository>();
  if (intro.introSeen) return;
  unawaited(intro.markIntroSeen());
  unawaited(
    context.read<AnalyticsRepository>().logLevelsIntro(action: 'shown'),
  );
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ZipColors.paper,
    builder: (_) => LevelsIntroSheet(overview: overview, home: context),
  );
}

class LevelsIntroSheet extends StatelessWidget {
  const LevelsIntroSheet({
    super.key,
    required this.overview,
    required this.home,
  });

  final LevelsOverview overview;

  /// Where the card was opened from; it navigates from there once closed.
  final BuildContext home;

  static const _games = [
    (id: GameIds.zip, icon: AppIcons.lightning, accent: ZipColors.ember),
    (id: GameIds.pathWords, icon: AppIcons.path, accent: ZipColors.sky),
  ];

  static String _title(String gameId) => gameId == GameIds.pathWords
      ? AppStrings.pathWordsTitle
      : AppStrings.zipTitle;

  void _play(BuildContext context, String gameId) {
    final next = overview.of(gameId);
    final analytics = context.read<AnalyticsRepository>();
    final intro = context.read<LevelsIntroRepository>();
    final preference = context.read<LevelsGamePreferenceRepository>();
    unawaited(intro.setLastGame(gameId));
    unawaited(analytics.logLevelsIntro(action: 'play', gameId: gameId));
    Navigator.of(context).pop();
    if (!home.mounted) return;
    if (next != null) {
      home.go(levelsOpenLocation(next.nextLevelId));
    } else {
      // Worlds not loaded: the map for that game; it loads them itself.
      unawaited(preference.write(gameId));
      home.go(levelsLocation);
    }
  }

  void _later(BuildContext context) {
    unawaited(
      context.read<AnalyticsRepository>().logLevelsIntro(action: 'later'),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ZipColors.ember.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: ZipColors.ember.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  AppStrings.levelsIntroBadge.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ZipColors.ember,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: AppIcon(AppIcons.levels, size: 44, color: ZipColors.star),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.levelsIntroTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppStrings.levelsIntroBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ZipColors.inkSoft,
              ),
            ),
            const SizedBox(height: 18),
            for (final game in _games) ...[
              _GameRow(
                title: _title(game.id),
                icon: game.icon,
                accent: game.accent,
                playLabel: AppStrings.levelNumber(
                  overview.of(game.id)?.nextNumber ?? 1,
                ),
                onPlay: () => _play(context, game.id),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 2),
            TextButton(
              onPressed: () => _later(context),
              child: Text(
                AppStrings.levelsIntroLater,
                style: const TextStyle(color: ZipColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.title,
    required this.icon,
    required this.accent,
    required this.playLabel,
    required this.onPlay,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String playLabel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: ZipColors.wall,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZipColors.glassBorder),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: AppIcon(icon, size: 22, color: accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: ZipColors.ink,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: onPlay,
            icon: const AppIcon(AppIcons.play, size: 16, color: ZipColors.ink),
            label: Text(
              playLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
