import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../results_args.dart';

/// Results of a cleared level: the time against the target, the three goals
/// (earned, or how to earn them), what improved, and the next level.
///
/// Deliberately still: the level's reward is the line drawn on the map
/// (Levels plan 3), not an effect here.
class LevelResultsView extends StatelessWidget {
  const LevelResultsView({super.key, required this.args});

  final ResultsArgs args;

  Future<void> _log(BuildContext context, String action) async {
    final gameId = args.gameId;
    if (gameId == null) return;
    await context.read<AnalyticsRepository?>()?.logResultsAction(
      gameId: gameId,
      action: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = args.local!;
    final level = info.level!;
    final theme = Theme.of(context);
    final time = AppStrings.formatPlayTime(args.timeSeconds);
    final target = level.targetSeconds;
    final targetText = target == null
        ? null
        : AppStrings.formatPlayTime(target);
    final next = level.nextLocation;
    final again = info.againLocation;
    final newBest = level.moreStars
        ? AppStrings.levelNewBestStars(level.previousStars!, level.bestStars)
        : args.improved
        ? AppStrings.levelNewBestTime
        : null;

    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Text(
                args.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                info.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ZipColors.inkSoft,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                targetText == null
                    ? time
                    : '$time · ${AppStrings.levelTarget(targetText)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: ZipColors.ember,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (newBest != null) ...[
                const SizedBox(height: 6),
                Text(
                  newBest,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ZipColors.success,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _Goal(earned: true, label: AppStrings.levelGoalClear),
              _Goal(
                earned: level.noHintsEarned,
                label: AppStrings.levelGoalNoHints,
                how: AppStrings.levelGoalNoHintsHow,
              ),
              if (targetText != null)
                _Goal(
                  earned: level.timeEarned,
                  label: AppStrings.levelGoalUnder(targetText),
                  how: AppStrings.levelGoalUnderHow(targetText),
                ),
              const SizedBox(height: 24),
              if (next != null)
                ZipPrimaryButton(
                  label: level.opensNewWorld
                      ? AppStrings.levelOpenWorld(level.nextWorldTheme!)
                      : AppStrings.levelNext,
                  icon: AppIcons.play,
                  onPressed: () async {
                    await _log(
                      context,
                      level.opensNewWorld ? 'open_world' : 'next_level',
                    );
                    if (!context.mounted) return;
                    context.pushReplacement(next);
                  },
                )
              else
                Text(
                  AppStrings.levelAllDone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              const SizedBox(height: 6),
              if (again != null)
                TextButton(
                  onPressed: () async {
                    await _log(context, 'replay');
                    if (!context.mounted) return;
                    context.pushReplacement(again);
                  },
                  child: Text(AppStrings.levelReplay),
                ),
              TextButton(
                onPressed: () async {
                  await _log(context, 'home');
                  if (!context.mounted) return;
                  context.go('/');
                },
                child: Text(AppStrings.backHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({required this.earned, required this.label, this.how});

  final bool earned;
  final String label;

  /// Shown under a missed goal.
  final String? how;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spoken = earned
        ? AppStrings.levelGoalEarned(label)
        : [AppStrings.levelGoalMissed(label), ?how].join('. ');
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              earned ? AppIcons.star : AppIcons.starOutline,
              size: 22,
              color: earned ? ZipColors.star : ZipColors.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyLarge),
                  if (!earned && how != null)
                    Text(
                      how!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZipColors.ember,
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
