import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/play_mode_route.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/level_goals.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/play_mode.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/levels_intro_repository.dart';
import '../results_args.dart';

/// Results of a cleared level: the stars this run earned, the time against
/// the target, the goals (earned, or how to earn them), what improved, and
/// the next level.
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
    final hasTarget = target != null && target > 0;
    final targetText = hasTarget ? AppStrings.formatPlayTime(target) : null;
    final maxStars = hasTarget ? 3 : 2;
    final next = level.nextLevelId;
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
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              _StarHero(stars: level.runStars, maxStars: maxStars),
              const SizedBox(height: 18),
              Text(
                args.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 350.ms),
              const SizedBox(height: 8),
              Center(
                child: _Pill(
                  icon: AppIcons.levels,
                  text: info.label,
                  color: ZipColors.sky,
                ),
              ),
              const SizedBox(height: 22),
              _TimeCard(
                    time: time,
                    targetText: targetText,
                    beatTarget: level.timeEarned,
                    newBest: newBest,
                  )
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 350.ms)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              _GoalsCard(
                    children: [
                      _Goal(
                        kind: LevelGoalKind.clear,
                        earned: true,
                        label: AppStrings.levelGoalClear,
                      ),
                      _Goal(
                        kind: LevelGoalKind.noHints,
                        earned: level.noHintsEarned,
                        label: AppStrings.levelGoalNoHints,
                        how: AppStrings.levelGoalNoHintsHow,
                      ),
                      if (targetText != null)
                        _Goal(
                          kind: LevelGoalKind.time,
                          earned: level.timeEarned,
                          label: AppStrings.levelGoalUnder(targetText),
                          how: AppStrings.levelGoalUnderHow(targetText),
                        ),
                    ],
                  )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 350.ms)
                  .slideY(begin: 0.08, end: 0),
              const _FirstClearTip(),
              const SizedBox(height: 24),
              if (next != null)
                ZipPrimaryButton(
                  label: level.opensNewWorld
                      ? AppStrings.levelOpenWorld(level.nextWorldName!)
                      : AppStrings.levelNext,
                  icon: AppIcons.play,
                  onPressed: () async {
                    await _log(
                      context,
                      level.opensNewWorld ? 'open_world' : 'next_level',
                    );
                    if (!context.mounted) return;
                    // Straight into the next board, in Results' place, so
                    // Back from it lands on the map. The player is signed
                    // in (they just played) and the clear unlocked it.
                    context.pushReplacement(
                      PlayMode.level(next).location(gameRoute(level.game)),
                    );
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppStrings.levelAllDone,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (again != null) ...[
                    Expanded(
                      child: _SecondaryButton(
                        icon: AppIcons.replay,
                        label: AppStrings.levelReplay,
                        onPressed: () async {
                          await _log(context, 'replay');
                          if (!context.mounted) return;
                          context.pushReplacement(again);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _SecondaryButton(
                      icon: AppIcons.levels,
                      label: AppStrings.levelBackToMap,
                      onPressed: () async {
                        await _log(context, 'map');
                        if (!context.mounted) return;
                        context.go(levelsLocation, extra: levelsVisitToken());
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The run's stars, the middle one raised, popping in one after another.
class _StarHero extends StatelessWidget {
  const _StarHero({required this.stars, required this.maxStars});

  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    final middle = (maxStars - 1) / 2;
    return Semantics(
      label: AppStrings.levelStarsLabel(stars, maxStars),
      excludeSemantics: true,
      child: SizedBox(
        height: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < maxStars; i++)
              Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 6,
                  bottom: (i - middle).abs() < 0.6 ? 18 : 0,
                ),
                child: _HeroStar(
                  earned: i < stars,
                  size: (i - middle).abs() < 0.6 ? 72 : 58,
                  delay: Duration(milliseconds: 120 + 160 * i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroStar extends StatelessWidget {
  const _HeroStar({
    required this.earned,
    required this.size,
    required this.delay,
  });

  final bool earned;
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final star = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: earned
            ? [
                BoxShadow(
                  color: ZipColors.star.withValues(alpha: 0.35),
                  blurRadius: size * 0.45,
                ),
              ]
            : const [],
      ),
      child: AppIcon(
        earned ? AppIcons.star : AppIcons.starOutline,
        size: size,
        color: earned ? ZipColors.star : ZipColors.outline,
      ),
    );
    if (!earned) return star.animate().fadeIn(delay: delay, duration: 300.ms);
    return star
        .animate()
        .fadeIn(delay: delay, duration: 200.ms)
        .scaleXY(
          delay: delay,
          begin: 0.3,
          end: 1,
          duration: 450.ms,
          curve: Curves.easeOutBack,
        );
  }
}

/// The run's time, big, beside the target, with what improved under them.
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.time,
    required this.targetText,
    required this.beatTarget,
    required this.newBest,
  });

  final String time;
  final String? targetText;
  final bool beatTarget;
  final String? newBest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetText = this.targetText;
    final timeColor = targetText == null || beatTarget
        ? ZipColors.success
        : ZipColors.ember;
    return _Card(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(AppIcons.timer, size: 26, color: timeColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  time,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: timeColor,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          if (targetText != null) ...[
            const SizedBox(height: 8),
            _Pill(
              icon: beatTarget ? AppIcons.checkCircle : AppIcons.flag,
              text: AppStrings.levelTarget(targetText),
              color: beatTarget ? ZipColors.success : ZipColors.inkSoft,
            ),
          ],
          if (newBest != null) ...[
            const SizedBox(height: 10),
            _Pill(
              icon: AppIcons.sparkle,
              text: newBest!,
              color: ZipColors.star,
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: ZipColors.outlineQuiet),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal({
    required this.kind,
    required this.earned,
    required this.label,
    this.how,
  });

  final LevelGoalKind kind;
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
    final accent = !earned
        ? ZipColors.outline
        : switch (kind) {
            LevelGoalKind.clear => ZipColors.success,
            LevelGoalKind.noHints => ZipColors.sky,
            LevelGoalKind.time => ZipColors.ember,
          };
    final icon = switch (kind) {
      LevelGoalKind.clear => AppIcons.flag,
      LevelGoalKind.noHints => AppIcons.noHints,
      LevelGoalKind.time => AppIcons.timer,
    };
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
              ),
              child: AppIcon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: earned ? ZipColors.onInk : ZipColors.inkSoft,
                    ),
                  ),
                  if (!earned && how != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      how!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ZipColors.ember,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIcon(
              earned ? AppIcons.star : AppIcons.starOutline,
              size: 24,
              color: earned ? ZipColors.star : ZipColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ZipColors.glassBorder),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: AppIcon(icon, size: 14, color: color)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ZipColors.onInk,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: ZipColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: AppIcon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// The first level cleared on this phone says how Levels go on: stars add up
/// on the map, and the next level is here or on the Levels tab. Once.
class _FirstClearTip extends StatefulWidget {
  const _FirstClearTip();

  @override
  State<_FirstClearTip> createState() => _FirstClearTipState();
}

class _FirstClearTipState extends State<_FirstClearTip> {
  late final bool _show;

  @override
  void initState() {
    super.initState();
    final intro = context.read<LevelsIntroRepository?>();
    _show = intro != null && !intro.firstClearTipSeen;
    if (_show) intro!.markFirstClearTipSeen();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child:
          Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: ZipColors.star.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ZipColors.star.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ExcludeSemantics(
                      child: AppIcon(
                        AppIcons.levels,
                        size: 20,
                        color: ZipColors.star,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.levelsFirstClearTip,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ZipColors.onInk,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: 500.ms, duration: 350.ms)
              .slideY(begin: 0.08, end: 0),
    );
  }
}
