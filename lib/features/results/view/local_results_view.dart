import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/haptics_service.dart';
import '../../../core/router/play_mode_route.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../path_words/view/widgets/path_words_results_panel.dart';
import '../results_args.dart';
import 'counting_play_time.dart';
import 'ember_burst.dart';

/// Results of a run off the dailies (archive, practice, bonus games): the
/// time (or score), what kind of run it was, and the local best. There is
/// no leaderboard, streak, share or achievement here: nothing of the
/// dailies changed.
class LocalResultsView extends StatelessWidget {
  const LocalResultsView({super.key, required this.args});

  final ResultsArgs args;

  LocalResultInfo get _info => args.local!;

  Future<void> _log(BuildContext context, String action) async {
    final gameId = args.gameId;
    if (gameId == null) return;
    await context.read<AnalyticsRepository?>()?.logResultsAction(
      gameId: gameId,
      action: action,
    );
  }

  void _back(BuildContext context, String fallback) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final again = info.againLocation;
    final isArchive = info.kind == LocalResultKind.archive;
    return Scaffold(
      body: ZipAtmosphere(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ZipMark(size: 40)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .scale(
                          begin: const Offset(0.7, 0.7),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 10),
                    Text(
                      args.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                    const SizedBox(height: 8),
                    Center(child: _RunLabel(label: info.label)),
                    const SizedBox(height: 16),
                    _LocalResultCard(args: args)
                        .animate()
                        .fadeIn(delay: 160.ms, duration: 450.ms)
                        .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                    if (args.pathWords != null) ...[
                      const SizedBox(height: 14),
                      PathWordsResultsPanel(
                        summary: args.pathWords!,
                        themeLabel: AppStrings.pathWordsThemeOf,
                      ).animate().fadeIn(delay: 600.ms),
                    ],
                    const SizedBox(height: 16),
                    if (isArchive)
                      ZipPrimaryButton(
                        label: AppStrings.backToArchive,
                        icon: Icons.calendar_month_rounded,
                        onPressed: () async {
                          await _log(context, 'archive');
                          if (!context.mounted) return;
                          _back(context, archiveLocation(args.gameId));
                        },
                      ).animate().fadeIn(delay: 300.ms)
                    else if (again != null)
                      ZipPrimaryButton(
                        label: info.kind == LocalResultKind.practice
                            ? AppStrings.practiceNewBoard
                            : AppStrings.playAgain,
                        icon: info.kind == LocalResultKind.practice
                            ? Icons.casino_rounded
                            : Icons.refresh_rounded,
                        onPressed: () async {
                          await _log(context, 'play_again');
                          if (!context.mounted) return;
                          context.pushReplacement(again);
                        },
                      ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () async {
                        await _log(context, 'home');
                        if (!context.mounted) return;
                        context.go('/');
                      },
                      child: const Text(AppStrings.backHome),
                    ).animate().fadeIn(delay: 380.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunLabel extends StatelessWidget {
  const _RunLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: ZipColors.skySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZipColors.sky.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: ZipColors.sky,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LocalResultCard extends StatefulWidget {
  const _LocalResultCard({required this.args});

  final ResultsArgs args;

  @override
  State<_LocalResultCard> createState() => _LocalResultCardState();
}

class _LocalResultCardState extends State<_LocalResultCard> {
  var _showBurst = false;

  void _landed() {
    if (!mounted || _showBurst) return;
    context.read<HapticsService?>()?.play(HapticKind.light);
    setState(() => _showBurst = true);
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final info = args.local!;
    final theme = Theme.of(context);
    final score = info.score;
    final bigStyle = theme.textTheme.displayLarge?.copyWith(
      color: ZipColors.ember,
      fontWeight: FontWeight.w900,
      letterSpacing: -2,
      height: 1,
      fontSize: 58,
      shadows: [
        Shadow(
          color: ZipColors.emberGlow.withValues(alpha: 0.75),
          blurRadius: 36,
        ),
      ],
    );
    final bestScore = info.bestScore;
    final bestSeconds = info.bestSeconds;
    final String? bestLine;
    if (score != null && bestScore != null) {
      bestLine = AppStrings.localBestScore(bestScore);
    } else if (bestSeconds != null) {
      final time = AppStrings.formatPlayTime(bestSeconds);
      bestLine = info.kind == LocalResultKind.archive
          ? AppStrings.archiveBest(time)
          : AppStrings.localBest(time);
    } else {
      bestLine = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        gradient: ZipColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
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
          SizedBox(
            height: 72,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (_showBurst) const Positioned.fill(child: EmberBurst()),
                if (score != null)
                  _ScoreText(score: score, style: bigStyle, onShown: _landed)
                else
                  CountingPlayTime(
                    timeSeconds: args.timeSeconds,
                    style: bigStyle,
                    onCompleted: _landed,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score != null
                ? (info.scoreLabel ?? AppStrings.resultsWordsLabel)
                      .toUpperCase()
                : AppStrings.resultsTimeLabel.toUpperCase(),
            style: theme.textTheme.titleSmall?.copyWith(
              color: ZipColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          if (args.improved) ...[
            const SizedBox(height: 12),
            ZipHudPill(
              icon: Icons.star_rounded,
              label: AppStrings.newLocalBest,
              emphasize: true,
            ),
          ],
          if (bestLine != null) ...[
            const SizedBox(height: 10),
            Text(
              bestLine,
              style: theme.textTheme.labelLarge?.copyWith(
                color: ZipColors.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreText extends StatefulWidget {
  const _ScoreText({
    required this.score,
    required this.style,
    required this.onShown,
  });

  final int score;
  final TextStyle? style;
  final VoidCallback onShown;

  @override
  State<_ScoreText> createState() => _ScoreTextState();
}

class _ScoreTextState extends State<_ScoreText> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onShown());
  }

  @override
  Widget build(BuildContext context) =>
      Text('${widget.score}', style: widget.style, textAlign: TextAlign.center);
}
