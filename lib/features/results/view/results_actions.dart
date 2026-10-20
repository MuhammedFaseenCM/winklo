import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_flags.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/zip_ui.dart';
import '../../../domain/failures.dart';
import '../../../domain/game_ids.dart';
import '../../../domain/play_period.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/share_repository.dart';
import '../../../domain/usecases/next_uncleared_daily.dart';
import '../logic/result_share_text.dart';
import '../results_args.dart';

/// What to do after clearing a daily: play the next uncleared one, share the
/// result, open the full board, or go home. Each tap logs a `results_action`.
class ResultsActions extends StatelessWidget {
  const ResultsActions({super.key, required this.args});

  final ResultsArgs args;

  String get _gameId => args.gameId!;

  Future<void> _log(BuildContext context, String action) {
    return context.read<AnalyticsRepository>().logResultsAction(
      gameId: _gameId,
      action: action,
    );
  }

  Future<void> _share(BuildContext context) async {
    final share = context.read<ShareRepository>();
    final analytics = context.read<AnalyticsRepository>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    await _log(context, 'share');
    final bool shared;
    try {
      shared = await share.shareText(
        resultShareText(
          gameId: _gameId,
          day: args.day ?? DateTime.now(),
          timeSeconds: args.timeSeconds,
          currentStreak: args.currentStreak,
          usedHints: args.usedHints,
          hadMistakes: args.hadMistakes,
        ),
      );
    } on Failure {
      messenger?.showSnackBar(SnackBar(content: Text(AppStrings.shareFailed)));
      return;
    }
    if (shared) await analytics.logShare(gameId: _gameId);
  }

  static String routeFor(String gameId) => switch (gameId) {
    GameIds.pathWords => '/path-words',
    GameIds.sudoku => '/sudoku',
    _ => '/zip',
  };

  static String titleFor(String gameId) => switch (gameId) {
    GameIds.pathWords => AppStrings.pathWordsTitle,
    GameIds.sudoku => AppStrings.sudokuTitle,
    _ => AppStrings.zipTitle,
  };

  @override
  Widget build(BuildContext context) {
    // The game routes open today's puzzle, so ask about today even when the
    // run just cleared was left open over midnight.
    final next = context.read<NextUnclearedDaily>()(
      justCleared: _gameId,
      playId: PlayPeriod.id(DateTime.now(), DevFlags.playPeriod),
    );

    Future<void> openBoard() async {
      await _log(context, 'leaderboard');
      if (!context.mounted) return;
      context.go('/leaderboard?game=$_gameId');
    }

    Future<void> goHome() async {
      await _log(context, 'home');
      if (!context.mounted) return;
      context.go('/');
    }

    final board = ResultsIconAction(
      tooltip: AppStrings.resultsFullBoard,
      icon: AppIcons.ranking,
      onPressed: openBoard,
    );
    final home = ResultsIconAction(
      tooltip: AppStrings.backHome,
      icon: AppIcons.home,
      onPressed: goHome,
    );

    // One row: icon buttons, then the main action. With nothing left to
    // play, sharing the day is the main action.
    final Widget bar;
    if (next != null) {
      bar = Row(
        children: [
          _OneAtATime(
            onPressed: () => _share(context),
            builder: (onPressed) => ResultsIconAction(
              tooltip: AppStrings.shareResult,
              icon: AppIcons.share,
              onPressed: onPressed,
            ),
          ),
          const SizedBox(width: 8),
          board,
          const SizedBox(width: 8),
          home,
          const SizedBox(width: 8),
          Expanded(
            child: _FittedPrimary(
              label: AppStrings.playNextGame(titleFor(next)),
              shortLabel: titleFor(next),
              icon: AppIcons.play,
              onPressed: () async {
                await _log(context, 'play_next');
                if (!context.mounted) return;
                context.pushReplacement(routeFor(next));
              },
            ),
          ),
        ],
      );
    } else {
      bar = Row(
        children: [
          board,
          const SizedBox(width: 8),
          home,
          const SizedBox(width: 8),
          Expanded(
            child: _OneAtATime(
              onPressed: () => _share(context),
              builder: (onPressed) => ZipPrimaryButton(
                label: AppStrings.shareResult,
                icon: AppIcons.share,
                compact: true,
                onPressed: onPressed,
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next == null) ...[
          Text(
            AppStrings.perfectDay,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ZipColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
        ],
        bar,
      ],
    );
  }
}

/// A 46 dp outlined icon button of the Results action bar.
class ResultsIconAction extends StatelessWidget {
  const ResultsIconAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Each icon button's side, and so the bar's height.
  static const double size = 46;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: AppIcon(icon, size: 20),
    );
  }
}

/// Builds a button that ignores taps until its last press finishes, so a
/// double tap can't open the share sheet twice.
class _OneAtATime extends StatefulWidget {
  const _OneAtATime({required this.onPressed, required this.builder});

  final Future<void> Function() onPressed;
  final Widget Function(VoidCallback? onPressed) builder;

  @override
  State<_OneAtATime> createState() => _OneAtATimeState();
}

class _OneAtATimeState extends State<_OneAtATime> {
  var _busy = false;

  Future<void> _press() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_busy ? null : _press);
}

/// The main button, with [shortLabel] when [label] won't fit on one line
/// beside the icon buttons ("Play Path Words next" on a 360 dp phone).
class _FittedPrimary extends StatelessWidget {
  const _FittedPrimary({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppLayout.of(context);
        // ZipPrimaryButton's compact label.
        final style =
            (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
                .copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.2,
                );
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        // Less the compact button's padding, icon and gap, and a little for
        // its border.
        final room =
            constraints.maxWidth -
            layout.compactButtonPadding.horizontal -
            layout.space(18) -
            layout.space(6) -
            4;
        final fits = painter.width <= room;
        painter.dispose();
        return ZipPrimaryButton(
          label: fits ? label : shortLabel,
          icon: icon,
          compact: true,
          onPressed: onPressed,
        );
      },
    );
  }
}
